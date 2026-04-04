import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:video_thumbnail/video_thumbnail.dart';
import 'package:video_player/video_player.dart';
import 'dart:ui';
import 'dart:io';
import 'dart:typed_data';
import '../theme/app_theme.dart';
import '../services/api_service.dart';
import 'result_screen.dart';

class AnalyzingScreen extends StatefulWidget {
  final XFile? mediaFile;
  final String? mediaUrl;
  final bool isVideo;

  const AnalyzingScreen({
    super.key,
    this.mediaFile,
    this.mediaUrl,
    this.isVideo = false,
  });

  @override
  State<AnalyzingScreen> createState() => _AnalyzingScreenState();
}

class _AnalyzingScreenState extends State<AnalyzingScreen> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  String _currentStep = 'Uploading to Server...';
  Uint8List? _videoPreviewBytes; // first extracted frame used as result screen preview

  // Simulated steps for UI feedback while waiting for API
  final List<String> _analysisSteps = [
    'Layer 1: Checking Cryptographic Provenance (C2PA)...',
    'Layer 2: Extracting Deep Learning Fingerprints...',
    'Layer 3: Performing Spectral FFT Analysis...',
    'Layer 4: Running Physics & ELA Sensor Analysis...',
    'Layer 5: YCbCr Chrominance Disconnect Scan...',
    'Aggregating 5-Layer Results via Reasoning Engine...',
  ];

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();
    
    // Change initial parsing message based on input type
    if (widget.mediaUrl != null) {
      _currentStep = 'Connecting to Instagram Servers...';
    } else if (widget.isVideo) {
      _currentStep = 'Extracting video frames (1/3)...';
    }

    _startAnalysis();
    _cycleStatusMessages();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _cycleStatusMessages() async {
    for (String step in _analysisSteps) {
      if (!mounted) return;
      await Future.delayed(const Duration(seconds: 2));
      if (mounted) {
        setState(() {
          _currentStep = step;
        });
      }
    }
  }

  /// Extracts 3 JPEG frames from a video at 25%, 50%, 75% of its duration.
  /// Returns a list of raw JPEG bytes for each frame.
  Future<List<Uint8List>> _extractVideoFrames(String videoPath) async {
    // Step 1: get video duration using VideoPlayerController
    final controller = VideoPlayerController.file(File(videoPath));
    await controller.initialize();
    final durationMs = controller.value.duration.inMilliseconds;
    await controller.dispose();

    final positions = [0.25, 0.50, 0.75];
    final labels = ['1/3 (25%)', '2/3 (50%)', '3/3 (75%)'];
    final frames = <Uint8List>[];

    for (int i = 0; i < positions.length; i++) {
      if (!mounted) break;
      setState(() => _currentStep = 'Extracting frame ${labels[i]}...');

      final timeMs = (durationMs * positions[i]).toInt();
      final bytes = await VideoThumbnail.thumbnailData(
        video: videoPath,
        imageFormat: ImageFormat.JPEG,
        timeMs: timeMs,
        quality: 90,
      );
      if (bytes != null) {
        frames.add(bytes);
        // Use the 25% frame as the preview image on the results screen
        if (i == 0) _videoPreviewBytes = bytes;
      }
    }
    return frames;
  }

  Future<void> _startAnalysis() async {
    try {
      final ApiService apiService = ApiService();
      Map<String, dynamic> result;

      if (widget.mediaUrl != null) {
        result = await apiService.analyzeUrl(widget.mediaUrl!);
      } else if (widget.isVideo && widget.mediaFile != null) {
        // Extract 3 frames on-device, then send only ~500 KB instead of the full video
        final frames = await _extractVideoFrames(widget.mediaFile!.path);
        if (frames.isEmpty) throw Exception('Could not extract frames from video.');
        if (mounted) setState(() => _currentStep = 'Running 5-layer analysis on 3 frames...');
        result = await apiService.analyzeVideoFrames(frames);
      } else if (widget.mediaFile != null) {
        result = await apiService.analyzeMedia(widget.mediaFile!);
      } else {
        throw Exception("No media was selected.");
      }

      if (!mounted) return;

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => ResultScreen(
            imageFile: widget.isVideo ? null : widget.mediaFile,
            videoPreviewBytes: _videoPreviewBytes,
            resultData: result,
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      if (e is InstagramBlockedException) {
        _showInstagramBlockedDialog();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Analysis Failed: $e'),
            backgroundColor: AppTheme.americanRed,
            duration: const Duration(seconds: 5),
          ),
        );
        Navigator.pop(context);
      }
    }
  }

  void _showInstagramBlockedDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppTheme.baseBlue.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.save_alt_rounded, color: AppTheme.baseBlue, size: 22),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Text(
                'One More Step',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Instagram Reels need to be on your device for a full forensic analysis. It only takes a few seconds:',
              style: TextStyle(fontSize: 14, height: 1.6, color: Color(0xFF555555)),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFF0F7FF),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppTheme.baseBlue.withOpacity(0.15)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _dialogStep('1', 'Go to the Reel in Instagram'),
                  const SizedBox(height: 10),
                  _dialogStep('2', 'Tap  ···  →  "Save to device"'),
                  const SizedBox(height: 10),
                  _dialogStep('3', 'Come back and tap the  +  button'),
                  const SizedBox(height: 10),
                  _dialogStep('4', 'Select the saved video from gallery'),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              Navigator.pop(context);
            },
            child: const Text('Cancel'),
          ),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.pop(ctx);
              Navigator.popUntil(context, (route) => route.isFirst);
            },
            icon: const Icon(Icons.video_library_rounded, size: 18),
            label: const Text('Upload from Gallery'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.baseBlue,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _dialogStep(String number, String text) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 22,
          height: 22,
          decoration: const BoxDecoration(
            color: AppTheme.baseBlue,
            shape: BoxShape.circle,
          ),
          child: Center(
            child: Text(
              number,
              style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(text, style: const TextStyle(fontSize: 13, height: 1.4, color: Color(0xFF333333))),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              AppTheme.americanWhite,
              const Color(0xFFF1F5F9),
            ],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Hero(
                    tag: 'upload_button',
                    child: AnimatedBuilder(
                      animation: _controller,
                      builder: (_, child) {
                        return Transform.rotate(
                          angle: _controller.value * 2 * 3.14159,
                          child: child,
                        );
                      },
                      child: Container(
                        decoration: BoxDecoration(
                          boxShadow: [
                            BoxShadow(
                              color: AppTheme.baseBlue.withOpacity(0.2),
                              blurRadius: 30,
                              offset: const Offset(0, 10),
                            )
                          ],
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(100),
                          child: BackdropFilter(
                            filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                            child: Material(
                              color: AppTheme.baseBlue,
                              child: Padding(
                                padding: const EdgeInsets.all(24),
                                child: const Icon(
                                  Icons.sync_rounded,
                                  size: 40,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 48),
                  Text(
                    'Analyzing Metadata\n& Pixel Forensics',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                      color: AppTheme.baseBlue,
                      height: 1.2,
                    ),
                  ),
                  const SizedBox(height: 32),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.6),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.white.withOpacity(0.8), width: 1),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.03),
                          blurRadius: 20,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            valueColor: AlwaysStoppedAnimation<Color>(AppTheme.baseBlue),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Text(
                            _currentStep,
                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.w500,
                              color: AppTheme.textDark,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
