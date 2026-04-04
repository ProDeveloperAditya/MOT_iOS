import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter/foundation.dart';
import 'dart:ui';
import 'dart:io';
import '../theme/app_theme.dart';

class ResultScreen extends StatefulWidget {
  final XFile? imageFile;
  final Uint8List? videoPreviewBytes;
  final Map<String, dynamic> resultData;

  const ResultScreen({
    super.key,
    this.imageFile,
    this.videoPreviewBytes,
    required this.resultData,
  });

  @override
  State<ResultScreen> createState() => _ResultScreenState();
}

class _ResultScreenState extends State<ResultScreen> {
  Uint8List? imageBytes;

  @override
  void initState() {
    super.initState();
    if (kIsWeb && widget.imageFile != null) {
      widget.imageFile!.readAsBytes().then((bytes) {
        setState(() {
          imageBytes = bytes;
        });
      });
    }
  }

  bool get isAi => widget.resultData['verdict'] == 'AI-Generated' || widget.resultData['verdict'] == 'Suspicious / Edited Photo';
  
  Color get statusColor => isAi ? AppTheme.americanRed : Colors.green[700]!;
  IconData get statusIcon => isAi ? Icons.warning_amber_rounded : Icons.verified_user_rounded;

  // Helper to safely get nested layer data
  Map<String, dynamic> _getLayer(String key) {
    final layers = widget.resultData['layers'];
    if (layers == null || layers[key] == null) return {};
    return Map<String, dynamic>.from(layers[key]);
  }

  String _getLayerStatus(String key) {
    final layer = _getLayer(key);
    if (layer.isEmpty) return 'Unavailable';
    
    // Prioritize new dedicated layer_status field
    final String s = (layer['layer_status'] ?? layer['status'] ?? '').toString().toLowerCase();
    
    if (s == 'ai') return 'AI Detected';
    if (s == 'suspicious' || s == 'anomaly') return 'Anomaly';
    if (s == 'normal' || s == 'clean' || s == 'correlated' || s == 'success') {
      // For backwards compatibility, if it's 'success', we still need to check strings
      // if it's not and explicitly 'normal', we return Normal.
      if (s != 'success') return 'Normal';
    } 
    if (s == 'active') return 'Active';
    if (s == 'missing') return 'Missing';
    if (s == 'error' || s == 'unavailable') return 'Unavailable';

    // Fallback logic for string-based detection (Old Backend or success status)
    switch (key) {
      case 'c2pa':
        return layer['detected'] == true ? 'Active' : 'Missing';
      case 'sightengine':
        if (layer['error'] != null) return 'Unavailable';
        final score = double.tryParse(layer['score'].toString()) ?? 0.0;
        return score > 0.5 ? 'AI Detected' : 'Clean';
      case 'exif':
        if (layer['error'] != null) return 'Unavailable';
        if (layer['ai_software_detected'] == true) return 'AI Detected';
        final gen = (layer['generator_type'] ?? '').toString();
        if (gen.contains('Real Camera')) return 'Clean';
        if (gen.contains('Likely AI') || gen.contains('Suspicious')) return 'Suspicious';
        if (gen.contains('Inconclusive')) return 'Inconclusive';
        return layer['layer_status']?.toString() == 'normal' ? 'Clean' : 'Suspicious';
      case 'physics':
        final gen = (layer['generator_type'] ?? '').toString();
        if (gen.contains('AI') || gen.contains('Anomaly') || gen.contains('Suspicious')) return 'Anomaly';
        return 'Normal';
      case 'hue':
        final gen = (layer['generator_type'] ?? '').toString();
        if (gen.contains('AI') || gen.contains('Mismatch')) return 'Mismatch';
        return 'Correlated';
      default:
        return 'Unknown';
    }
  }

  String _getLayerDetails(String key) {
    final layer = _getLayer(key);
    if (layer.isEmpty) return 'Layer data unavailable for this scan.';
    
    switch (key) {
      case 'c2pa':
        return 'Generator: ${(layer['generator'] ?? 'Unknown').toString().replaceAll('_', ' ')}';
      case 'sightengine':
        if (layer['error'] != null) return 'Sightengine service unavailable.';
        final score = double.tryParse(layer['score'].toString()) ?? 0.0;
        if (score > 0.8) return 'Strong synthetic artifacts detected (${(score * 100).toStringAsFixed(1)}% confidence).';
        if (score > 0.5) return 'Unusual AI-like patterns found (${(score * 100).toStringAsFixed(1)}% confidence).';
        return 'Image appears authentic to neural analysis.';
      case 'exif':
        if (layer['error'] != null) return 'EXIF analysis unavailable.';
        return layer['details'] ?? 'EXIF metadata analyzed.';
      case 'physics':
        return layer['details'] ?? 'Physics analysis complete.';
      case 'hue':
        return layer['details'] ?? 'Chrominance analysis complete.';
      default:
        return 'No details available.';
    }
  }

  @override
  Widget build(BuildContext context) {
    final double confidenceRaw = double.tryParse(widget.resultData['confidence'].toString()) ?? 0.0;
    final int confidencePercent = (confidenceRaw * 100).toInt();
    
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        flexibleSpace: ClipRRect(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
            child: Container(color: Colors.transparent),
          ),
        ),
        title: const Text('ANALYSIS RESULT'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () => Navigator.popUntil(context, (route) => route.isFirst),
        ),
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Glassmorphic Header with Circular Gauge
            Container(
              height: 400,
              decoration: BoxDecoration(
                color: (widget.imageFile == null && widget.videoPreviewBytes == null)
                    ? AppTheme.baseBlue
                    : null,
                image: widget.videoPreviewBytes != null
                    ? DecorationImage(
                        image: MemoryImage(widget.videoPreviewBytes!),
                        fit: BoxFit.cover,
                      )
                    : widget.imageFile != null
                        ? DecorationImage(
                            image: kIsWeb
                                ? (imageBytes != null
                                        ? MemoryImage(imageBytes!)
                                        : NetworkImage(widget.imageFile!.path))
                                    as ImageProvider
                                : FileImage(File(widget.imageFile!.path))
                                    as ImageProvider,
                            fit: BoxFit.cover,
                          )
                        : null,
              ),
              child: ClipRRect(
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
                  child: Container(
                    color: AppTheme.americanWhite.withOpacity(0.6),
                    child: SafeArea(
                      bottom: false,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const SizedBox(height: 20),
                          // Circular Confidence Gauge
                          Container(
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: statusColor.withOpacity(0.2),
                                  blurRadius: 30,
                                  spreadRadius: 5,
                                ),
                              ],
                            ),
                            child: SizedBox(
                              width: 150,
                              height: 150,
                              child: Stack(
                                fit: StackFit.expand,
                                children: [
                                  CircularProgressIndicator(
                                    value: 1.0,
                                    strokeWidth: 14,
                                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white.withOpacity(0.5)),
                                  ),
                                  CircularProgressIndicator(
                                    value: confidenceRaw,
                                    strokeWidth: 14,
                                    strokeCap: StrokeCap.round,
                                    valueColor: AlwaysStoppedAnimation<Color>(statusColor),
                                  ),
                                  Center(
                                    child: Column(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Icon(statusIcon, color: statusColor, size: 32),
                                        const SizedBox(height: 4),
                                        Text(
                                          '$confidencePercent%',
                                          style: const TextStyle(
                                            fontSize: 32,
                                            fontWeight: FontWeight.w800,
                                            color: AppTheme.textDark,
                                            letterSpacing: -1,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 32),
                          // Verdict Pill
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
                            decoration: BoxDecoration(
                              color: statusColor,
                              borderRadius: BorderRadius.circular(30),
                              boxShadow: [
                                BoxShadow(
                                  color: statusColor.withOpacity(0.3),
                                  blurRadius: 15,
                                  offset: const Offset(0, 5),
                                ),
                              ],
                            ),
                            child: Text(
                              widget.resultData['verdict'].toString().toUpperCase(),
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w800,
                                fontSize: 18,
                                letterSpacing: 1.5,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
            
            // Details Section
            Container(
              decoration: BoxDecoration(
                color: AppTheme.americanWhite,
              ),
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Evaluation Summary',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      color: AppTheme.baseBlue,
                      fontSize: 20,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    widget.resultData['summary'] ?? '',
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(height: 1.6),
                  ),
                  const SizedBox(height: 40),
                  
                  Text(
                    '5-Layer Forensic Breakdown',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      color: AppTheme.baseBlue,
                      fontSize: 20,
                    ),
                  ),
                  const SizedBox(height: 20),
                  
                  // Layer 1: Sightengine Neural API (highest weight)
                  _buildLayerCard(
                    context,
                    title: 'Layer 1: Neural AI Detection',
                    status: _getLayerStatus('sightengine'),
                    details: _getLayerDetails('sightengine'),
                    icon: Icons.psychology_rounded,
                  ),
                  const SizedBox(height: 16),

                  // Layer 2: Physics / ELA
                  _buildLayerCard(
                    context,
                    title: 'Layer 2: Physics / ELA',
                    status: _getLayerStatus('physics'),
                    details: _getLayerDetails('physics'),
                    icon: Icons.science_rounded,
                  ),
                  const SizedBox(height: 16),

                  // Layer 3: EXIF Metadata Forensics
                  _buildLayerCard(
                    context,
                    title: 'Layer 3: EXIF Metadata',
                    status: _getLayerStatus('exif'),
                    details: _getLayerDetails('exif'),
                    icon: Icons.photo_camera_rounded,
                  ),
                  const SizedBox(height: 16),

                  // Layer 4: Chrominance / Hue
                  _buildLayerCard(
                    context,
                    title: 'Layer 4: Chrominance',
                    status: _getLayerStatus('hue'),
                    details: _getLayerDetails('hue'),
                    icon: Icons.palette_rounded,
                  ),
                  const SizedBox(height: 16),

                  // Layer 5: C2PA Cryptographic Provenance
                  _buildLayerCard(
                    context,
                    title: 'Layer 5: C2PA Cryptography',
                    status: _getLayerStatus('c2pa'),
                    details: _getLayerDetails('c2pa'),
                    icon: Icons.fingerprint_rounded,
                  ),

                  // Video Frame Breakdown (only shown for video results)
                  if (widget.resultData['video_analysis'] != null) ...[
                    const SizedBox(height: 40),
                    Text(
                      'Video Frame Breakdown',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: AppTheme.baseBlue,
                        fontSize: 20,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '3 frames extracted on-device and analyzed independently',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppTheme.textLight,
                      ),
                    ),
                    const SizedBox(height: 16),
                    _buildVideoFrameCard(context, widget.resultData['video_analysis']),
                  ],

                  const SizedBox(height: 48),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () => Navigator.popUntil(context, (route) => route.isFirst),
                      icon: const Icon(Icons.refresh_rounded),
                      label: const Text('SCAN ANOTHER ITEM'),
                    ),
                  ),
                  const SizedBox(height: 32),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVideoFrameCard(BuildContext context, Map<String, dynamic> va) {
    final positions = List<String>.from(va['frame_positions'] ?? []);
    final verdicts = List<String>.from(va['frame_verdicts'] ?? []);
    final rawConfs = va['frame_confidences'] ?? [];
    final confidences = List<double>.from(
      rawConfs.map((c) => double.tryParse(c.toString()) ?? 0.0),
    );

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        children: [
          for (int i = 0; i < positions.length; i++) ...[
            if (i > 0) const Divider(height: 24, color: Color(0xFFF0F0F0)),
            _buildFrameRow(
              context,
              position: positions[i],
              verdict: i < verdicts.length ? verdicts[i] : '—',
              confidence: i < confidences.length ? confidences[i] : 0.0,
            ),
          ],
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFFF8F9FF),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                const Icon(Icons.info_outline_rounded, size: 14, color: AppTheme.textLight),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'Aggregated: max confidence × 0.60 + mean × 0.40',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppTheme.textLight,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFrameRow(BuildContext context, {
    required String position,
    required String verdict,
    required double confidence,
  }) {
    final bool isAiVerdict = verdict == 'AI-Generated';
    final bool isRealVerdict = verdict == 'Real Camera';

    Color badgeColor;
    Color badgeTextColor;
    IconData icon;

    if (isAiVerdict) {
      badgeColor = const Color(0xFFFEE2E2);
      badgeTextColor = AppTheme.americanRed;
      icon = Icons.warning_amber_rounded;
    } else if (isRealVerdict) {
      badgeColor = Colors.green[50]!;
      badgeTextColor = Colors.green[700]!;
      icon = Icons.check_circle_outline_rounded;
    } else {
      badgeColor = Colors.amber[50]!;
      badgeTextColor = Colors.amber[800]!;
      icon = Icons.help_outline_rounded;
    }

    return Row(
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: const Color(0xFFF0F4FF),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Center(
            child: Text(
              position,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: AppTheme.baseBlue,
              ),
            ),
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: badgeColor,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                Icon(icon, size: 14, color: badgeTextColor),
                const SizedBox(width: 6),
                Text(
                  verdict,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: badgeTextColor,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 12),
        Text(
          '${(confidence * 100).toStringAsFixed(1)}%',
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: AppTheme.textDark,
          ),
        ),
      ],
    );
  }

  Widget _buildLayerCard(BuildContext context, {required String title, required String status, required String details, required IconData icon}) {
    // Determine card styling based on status
    final bool isAlertStatus = ['Active', 'AI Detected', 'GAN', 'Diffusion', 'Anomaly', 'Mismatch'].contains(status);
    final bool isCleanStatus = ['Clean', 'Normal', 'Correlated'].contains(status);
    final bool isNeutralStatus = ['Inconclusive', 'Missing', 'Unknown'].contains(status);
    
    Color badgeColor;
    Color badgeTextColor;
    if (isAlertStatus) {
      badgeColor = const Color(0xFFFEE2E2);
      badgeTextColor = AppTheme.americanRed;
    } else if (isCleanStatus) {
      badgeColor = Colors.green[50]!;
      badgeTextColor = Colors.green[700]!;
    } else if (isNeutralStatus) {
      badgeColor = Colors.amber[50]!;
      badgeTextColor = Colors.amber[800]!;
    } else {
      badgeColor = Colors.grey[100]!;
      badgeTextColor = AppTheme.textLight;
    }
    
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppTheme.americanWhite,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: AppTheme.baseBlue, size: 28),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        title,
                        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16, color: AppTheme.textDark),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: badgeColor,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        status,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: badgeTextColor,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  details,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(height: 1.5),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
