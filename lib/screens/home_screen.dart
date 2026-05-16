import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:ui';
import '../theme/app_theme.dart';
import 'analyzing_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with WidgetsBindingObserver, TickerProviderStateMixin {
  final ImagePicker _picker = ImagePicker();
  final TextEditingController _urlController = TextEditingController();
  static const _shareChannel = MethodChannel('com.ministryoftruth/share');

  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;
  late AnimationController _rippleController;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Check for shared file on cold start (after first frame renders)
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkForSharedFile());

    // Pulse: button gently scales up and down
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1800),
      vsync: this,
    )..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.08).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    // Ripple: expanding rings around the button
    _rippleController = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    )..repeat();
  }

  @override
  void dispose() {
    _urlController.dispose();
    _pulseController.dispose();
    _rippleController.dispose();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Check for shared file when app comes back to foreground (hot start share)
    if (state == AppLifecycleState.resumed) {
      _checkForSharedFile();
    }
  }

  /// Checks native side for any shared media via MethodChannel.
  Future<void> _checkForSharedFile() async {
    try {
      final String? path = await _shareChannel.invokeMethod('getSharedFile');
      if (path != null && path.isNotEmpty) {
        if (path.startsWith('http')) {
          _navigateToAnalysisUrl(path);
        } else {
          final isVideo = path.endsWith('.mp4') || path.endsWith('.mov');
          _navigateToAnalysis(XFile(path), isVideo);
        }
      }
    } catch (e) {
      debugPrint('Share check error: $e');
    }
  }

  void _navigateToAnalysis(XFile media, bool isVideo) {
    if (!mounted) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AnalyzingScreen(
          mediaFile: media,
          isVideo: isVideo,
        ),
      ),
    );
  }

  void _navigateToAnalysisUrl(String url) {
    if (!mounted) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AnalyzingScreen(
          mediaUrl: url,
        ),
      ),
    );
  }

  Future<void> _pickMedia(bool isVideo, ImageSource source) async {
    try {
      final XFile? media = isVideo
          ? await _picker.pickVideo(source: source)
          : await _picker.pickImage(source: source);

      if (media != null) {
        _navigateToAnalysis(media, isVideo);
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error picking media: $e'),
          backgroundColor: AppTheme.americanRed,
        ),
      );
    }
  }

  void _showPickerOptions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (BuildContext context) {
        return ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
            child: Container(
              color: AppTheme.americanWhite.withOpacity(0.7),
              child: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: Colors.black12,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      const SizedBox(height: 24),
                      Text(
                        'Upload Media',
                        style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                          color: AppTheme.baseBlue,
                        ),
                      ),
                      const SizedBox(height: 32),
                      _buildModalAction(
                        icon: Icons.photo_library_rounded,
                        title: 'Choose Photo',
                        subtitle: 'From gallery',
                        onTap: () {
                          Navigator.pop(context);
                          _pickMedia(false, ImageSource.gallery);
                        },
                      ),
                      const SizedBox(height: 16),
                      _buildModalAction(
                        icon: Icons.video_library_rounded,
                        title: 'Choose Video',
                        subtitle: 'From gallery (.mp4, .mov)',
                        onTap: () {
                          Navigator.pop(context);
                          _pickMedia(true, ImageSource.gallery);
                        },
                      ),
                      const SizedBox(height: 16),
                      _buildModalAction(
                        icon: Icons.camera_alt_rounded,
                        title: 'Take Photo',
                        subtitle: 'Use camera',
                        onTap: () {
                          Navigator.pop(context);
                          _pickMedia(false, ImageSource.camera);
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildModalAction({required IconData icon, required String title, required String subtitle, required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.6),
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
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.baseBlue.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: AppTheme.baseBlue, size: 28),
            ),
            const SizedBox(width: 20),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 18, color: AppTheme.textDark)),
                  const SizedBox(height: 4),
                  Text(subtitle, style: const TextStyle(color: AppTheme.textLight, fontSize: 14)),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded, color: Colors.black26),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: true,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        flexibleSpace: ClipRRect(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
            child: Container(
              color: AppTheme.americanWhite.withOpacity(0.7),
            ),
          ),
        ),
        title: const Text('MINISTRY OF TRUTH'),
      ),
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
          child: Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const SizedBox(height: 40),
                        Container(
                          padding: const EdgeInsets.all(32),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.5),
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: AppTheme.baseBlue.withOpacity(0.05),
                                blurRadius: 40,
                                spreadRadius: 10,
                              )
                            ],
                          ),
                          child: const Icon(
                            Icons.fingerprint_rounded,
                            size: 100,
                            color: AppTheme.baseBlue,
                          ),
                        ),
                        const SizedBox(height: 48),
                        Text(
                          'Verify Digital\nAuthenticity',
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                            height: 1.1,
                          ),
                        ),
                        const SizedBox(height: 20),
                        Text(
                          'Upload media to detect AI generation, deepfakes, and alterations using our Penta-Layer Forensic Defense Architecture.',
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                            color: AppTheme.textLight,
                            height: 1.6,
                          ),
                        ),
                        const SizedBox(height: 32),
                        // URL Input Bar
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(30),
                            boxShadow: [
                              BoxShadow(
                                color: AppTheme.baseBlue.withOpacity(0.08),
                                blurRadius: 15,
                                offset: const Offset(0, 5),
                              )
                            ],
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.link_rounded, color: AppTheme.baseBlue),
                              const SizedBox(width: 12),
                              Expanded(
                                child: TextField(
                                  controller: _urlController,
                                  decoration: const InputDecoration(
                                    border: InputBorder.none,
                                    hintText: 'Paste YouTube or Instagram link...',
                                    hintStyle: TextStyle(color: Colors.black38),
                                  ),
                                  onSubmitted: (value) {
                                    if (value.isNotEmpty && value.startsWith('http')) {
                                      _navigateToAnalysisUrl(value);
                                      _urlController.clear();
                                    }
                                  },
                                ),
                              ),
                              IconButton(
                                onPressed: () {
                                  if (_urlController.text.isNotEmpty && _urlController.text.startsWith('http')) {
                                    _navigateToAnalysisUrl(_urlController.text);
                                    _urlController.clear();
                                  }
                                },
                                icon: const Icon(Icons.arrow_forward_rounded, color: AppTheme.baseBlue),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: const [
                            SizedBox(width: 4),
                            Icon(Icons.info_outline_rounded, size: 13, color: Colors.black38),
                            SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                'For Instagram Reels, saving to your gallery first gives the most accurate results.',
                                style: TextStyle(fontSize: 12, color: Colors.black38, height: 1.4),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 48),
                        Center(
                          child: SizedBox(
                            width: 220,
                            height: 220,
                            child: Stack(
                              alignment: Alignment.center,
                              children: [
                                // Ripple ring 1
                                AnimatedBuilder(
                                  animation: _rippleController,
                                  builder: (context, child) {
                                    final v = _rippleController.value;
                                    return Container(
                                      width: 88 + 90 * v,
                                      height: 88 + 90 * v,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        border: Border.all(
                                          color: AppTheme.baseBlue.withOpacity((1 - v) * 0.35),
                                          width: 2,
                                        ),
                                      ),
                                    );
                                  },
                                ),
                                // Ripple ring 2 — half a cycle behind ring 1
                                AnimatedBuilder(
                                  animation: _rippleController,
                                  builder: (context, child) {
                                    final v = (_rippleController.value + 0.5) % 1.0;
                                    return Container(
                                      width: 88 + 90 * v,
                                      height: 88 + 90 * v,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        border: Border.all(
                                          color: AppTheme.baseBlue.withOpacity((1 - v) * 0.35),
                                          width: 2,
                                        ),
                                      ),
                                    );
                                  },
                                ),
                                // The + button with pulse scale
                                AnimatedBuilder(
                                  animation: _pulseAnimation,
                                  builder: (context, child) => Transform.scale(
                                    scale: _pulseAnimation.value,
                                    child: child,
                                  ),
                                  child: Hero(
                                    tag: 'upload_button',
                                    child: Container(
                                      decoration: BoxDecoration(
                                        boxShadow: [
                                          BoxShadow(
                                            color: AppTheme.baseBlue.withOpacity(0.3),
                                            blurRadius: 30,
                                            offset: const Offset(0, 15),
                                          )
                                        ],
                                      ),
                                      child: ClipRRect(
                                        borderRadius: BorderRadius.circular(100),
                                        child: BackdropFilter(
                                          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                                          child: Material(
                                            color: AppTheme.baseBlue,
                                            child: InkWell(
                                              onTap: () => _showPickerOptions(context),
                                              child: const Padding(
                                                padding: EdgeInsets.all(24),
                                                child: Icon(
                                                  Icons.add_rounded,
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
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 48),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
