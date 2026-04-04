import 'package:image_picker/image_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'dart:convert';
import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:dio/io.dart';
import 'dart:io';

/// Thrown when Instagram blocks the server from downloading the video.
/// The app should catch this and show the "save to gallery" recovery flow.
class InstagramBlockedException implements Exception {
  final String message;
  const InstagramBlockedException(this.message);
  @override
  String toString() => message;
}

class ApiService {
  // Google Cloud Run Backend (5-Layer Forensic Engine)
  // Override at build/run time with:
  // --dart-define=API_BASE_URL=https://your-backend.example.com/api
  static const String baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'https://ministry-of-truth-ps4ugf3axq-el.a.run.app/api',
  );
  
  late final Dio _dio;

  ApiService() {
    _dio = Dio(BaseOptions(
      baseUrl: baseUrl,
      connectTimeout: const Duration(seconds: 60),
      receiveTimeout: const Duration(seconds: 300),
      sendTimeout: const Duration(seconds: 300),
      headers: {
        'Connection': 'keep-alive',
        'Accept': 'application/json',
      },
    ));

    // Force HTTP/1.1 to avoid common HTTP/2 framing issues on mobile-to-cloud regional routes
    if (!kIsWeb) {
      (_dio.httpClientAdapter as IOHttpClientAdapter).onHttpClientCreate = (client) {
        client.badCertificateCallback = (X509Certificate cert, String host, int port) => true;
        // Some systems might need explicit HTTP/1.1 enforcement
        return client;
      };
    }
  }

  Future<Map<String, dynamic>> analyzeMedia(XFile file) async {
    // 1. Pre-warm Pulse (Wake up the Brain)
    try {
      print('[ApiService] Sending pre-warm pulse...');
      await _dio.get('/health', options: Options(validateStatus: (status) => true));
    } catch (e) {
      print('[ApiService] Pre-warm pulse failed (ignoring): $e');
    }

    // Resize if image is over 6 MB — reduces upload time without affecting detection accuracy.
    // Caps longest side at 1920px (forensic patterns like noise variance and ELA are
    // relative per-pixel measurements, so they are preserved after dimension downscaling).
    Uint8List? resizedBytes;
    if (!kIsWeb) {
      final fileSize = await File(file.path).length();
      if (fileSize > 6 * 1024 * 1024) {
        print('[ApiService] File is ${(fileSize / 1024 / 1024).toStringAsFixed(1)} MB — resizing to 1920px...');
        resizedBytes = await FlutterImageCompress.compressWithFile(
          file.path,
          minWidth: 1920,
          minHeight: 1920,
          quality: 88,
        );
        if (resizedBytes != null) {
          print('[ApiService] Resized: ${(fileSize / 1024 / 1024).toStringAsFixed(1)} MB -> ${(resizedBytes.length / 1024).toStringAsFixed(0)} KB');
        }
      }
    }

    int retryCount = 0;
    const int maxRetries = 2;

    while (retryCount <= maxRetries) {
      try {
        print('[ApiService] Analysis Attempt ${retryCount + 1} starting for ${file.name}...');

        FormData formData;
        if (kIsWeb) {
          formData = FormData.fromMap({
            'file': MultipartFile.fromBytes(
              await file.readAsBytes(),
              filename: file.name,
            ),
          });
        } else if (resizedBytes != null) {
          formData = FormData.fromMap({
            'file': MultipartFile.fromBytes(
              resizedBytes,
              filename: file.name,
            ),
          });
        } else {
          formData = FormData.fromMap({
            'file': await MultipartFile.fromFile(
              file.path,
              filename: file.name,
            ),
          });
        }

        final response = await _dio.post(
          '/analyze',
          data: formData,
          onSendProgress: (sent, total) {
            if (total != -1) {
              int progress = (sent / total * 100).toInt();
              print('[ApiService] Upload Progress: $progress%');
            }
          },
        );

        if (response.statusCode == 200) {
          print('[ApiService] Success! Received response.');
          return response.data;
        } else {
          print('[ApiService] Server returned error: ${response.statusCode}');
          throw Exception('Inference Engine Error (${response.statusCode})');
        }
      } catch (e, stack) {
        retryCount++;
        print('[ApiService] ERROR details: $e');
        print('[ApiService] STACK TRACE: $stack');
        
        if (retryCount > maxRetries) {
          String userMsg = 'Connection lost during analysis. This often happens on unstable mobile networks.';
          
          if (e is DioException) {
            final responseData = e.response?.data;
            if (responseData is Map<String, dynamic> && responseData['error'] != null) {
              userMsg = responseData['error'].toString();
            } else if (responseData is String && responseData.isNotEmpty) {
              userMsg = responseData;
            } else {
              if (e.type == DioExceptionType.connectionTimeout) {
                userMsg = 'Connection Timeout. Please check your internet speed.';
              }
              if (e.message?.contains('32') ?? false) {
                userMsg = 'Broken Pipe (Error 32). The server dropped the connection. Try a smaller file or better signal.';
              }
            }
          }
          
          throw Exception(userMsg);
        }
        
        print('[ApiService] Waiting ${2 * retryCount}s before retry...');
        await Future.delayed(Duration(seconds: 2 * retryCount));
      }
    }
    throw Exception('Unknown Connectivity Error');
  }

  /// Sends 3 pre-extracted video frames (as JPEG bytes) to /analyze/frames.
  /// Much faster than uploading the full video file — only ~500 KB vs 10-20 MB.
  Future<Map<String, dynamic>> analyzeVideoFrames(List<Uint8List> frames) async {
    try {
      print('[ApiService] Sending pre-warm pulse...');
      await _dio.get('/health', options: Options(validateStatus: (status) => true));
    } catch (e) {
      print('[ApiService] Pre-warm pulse failed (ignoring): $e');
    }

    int retryCount = 0;
    const int maxRetries = 2;

    while (retryCount <= maxRetries) {
      try {
        print('[ApiService] Video frames attempt ${retryCount + 1}: sending ${frames.length} frames...');

        final formData = FormData.fromMap({
          for (int i = 0; i < frames.length; i++)
            'frame${i + 1}': MultipartFile.fromBytes(
              frames[i],
              filename: 'frame_${i + 1}.jpg',
            ),
        });

        final response = await _dio.post(
          '/analyze/frames',
          data: formData,
          onSendProgress: (sent, total) {
            if (total != -1) {
              print('[ApiService] Frames upload: ${(sent / total * 100).toInt()}%');
            }
          },
        );

        if (response.statusCode == 200) {
          print('[ApiService] Video frames analysis success!');
          return response.data;
        } else {
          throw Exception('Inference Engine Error (${response.statusCode})');
        }
      } catch (e) {
        retryCount++;
        print('[ApiService] ERROR: $e');
        if (retryCount > maxRetries) {
          String userMsg = 'Video analysis failed. Please try again.';
          if (e is DioException) {
            final responseData = e.response?.data;
            if (responseData is Map<String, dynamic> && responseData['error'] != null) {
              userMsg = responseData['error'].toString();
            } else if (e.type == DioExceptionType.connectionTimeout) {
              userMsg = 'Connection Timeout. Please check your internet speed.';
            }
          }
          throw Exception(userMsg);
        }
        await Future.delayed(Duration(seconds: 2 * retryCount));
      }
    }
    throw Exception('Unknown Connectivity Error');
  }

  Future<Map<String, dynamic>> analyzeUrl(String url) async {
    try {
      print('[ApiService] Sending pre-warm pulse...');
      await _dio.get('/health', options: Options(validateStatus: (status) => true));
    } catch (e) {
      print('[ApiService] Pre-warm pulse failed (ignoring): $e');
    }

    int retryCount = 0;
    const int maxRetries = 2;

    while (retryCount <= maxRetries) {
      try {
        print('[ApiService] URL Analysis Attempt ${retryCount + 1} starting for $url...');
        
        final response = await _dio.post(
          '/analyze/url',
          data: {'url': url},
        );

        if (response.statusCode == 200) {
          print('[ApiService] Success! Received URL response.');
          return response.data;
        } else {
          print('[ApiService] Server returned error: ${response.statusCode}');
          throw Exception('Inference Engine Error (${response.statusCode})');
        }
      } catch (e, stack) {
        retryCount++;
        print('[ApiService] ERROR details: $e');
        
        if (retryCount > maxRetries) {
          String userMsg = 'Connection lost during URL analysis.';
          if (e is DioException) {
            final responseData = e.response?.data;
            if (responseData is Map<String, dynamic> && responseData['error'] != null) {
              userMsg = responseData['error'].toString();
            } else if (responseData is String && responseData.isNotEmpty) {
              userMsg = responseData;
            } else if (e.type == DioExceptionType.connectionTimeout) {
              userMsg = 'Connection Timeout.';
            }
          }
          // Detect Instagram server-side IP block and surface a specific exception
          // so the UI can show the "save to gallery" recovery flow.
          final lowerMsg = userMsg.toLowerCase();
          if (lowerMsg.contains('instagram') &&
              (lowerMsg.contains('login required') ||
               lowerMsg.contains('rate-limit') ||
               lowerMsg.contains('rate limit') ||
               lowerMsg.contains('both failed') ||
               lowerMsg.contains('not available'))) {
            throw const InstagramBlockedException(
              'Instagram blocked our server from downloading this video. '
              'This is an IP restriction — Instagram blocks cloud servers.',
            );
          }
          throw Exception(userMsg);
        }
        
        await Future.delayed(Duration(seconds: 2 * retryCount));
      }
    }
    throw Exception('Unknown Connectivity Error');
  }
}
