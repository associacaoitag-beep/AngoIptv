import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:provider/provider.dart';
import '../providers/channel_provider.dart';
import '../utils/app_colors.dart';
import 'home_screen.dart';
import 'privacy_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  late AnimationController _rotationController;
  late AnimationController _fadeController;
  late AnimationController _pulseController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _pulseAnimation;


  bool _showSecondaryText = false;
  int _dotCount = 0;

  @override
  void initState() {
    super.initState();
    _setupAnimations();
    _startLoading();
  }

  void _setupAnimations() {
    _rotationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();

    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..repeat(reverse: true);

    _fadeAnimation = Tween<double>(begin: 1.0, end: 0.0).animate(
      CurvedAnimation(parent: _fadeController, curve: Curves.easeInOut),
    );

    _pulseAnimation = Tween<double>(begin: 0.7, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    // Animate dots
    Future.delayed(const Duration(milliseconds: 500), _animateDots);

    // Show secondary text after 2 seconds
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) {
        setState(() => _showSecondaryText = true);
      }
    });
  }

  void _animateDots() {
    if (!mounted) return;
    setState(() {
      _dotCount = (_dotCount + 1) % 4;
    });
    Future.delayed(const Duration(milliseconds: 400), _animateDots);
  }

  Future<void> _startLoading() async {
    try {
      // Check privacy accepted
      final prefs = await SharedPreferences.getInstance();
      final privacyAccepted = prefs.getBool('privacy_accepted') ?? false;

      if (kDebugMode) debugPrint('🔐 Privacy accepted: $privacyAccepted');

      // Load channels - ChannelService.initHive() já foi chamado em main.dart
      if (mounted) {
        if (kDebugMode) debugPrint('📥 Starting channel loading from SplashScreen...');
        final provider = context.read<ChannelProvider>();
        await provider.loadChannels();
        if (kDebugMode) debugPrint('✅ Channel loading completed');
      }

      await Future.delayed(const Duration(milliseconds: 800));

      if (!mounted) return;

      // Fade out
      await _fadeController.forward();

      if (!mounted) return;

      // Navigate
      if (kDebugMode) debugPrint('🚀 Navigating to ${privacyAccepted ? 'HomeScreen' : 'PrivacyScreen'}');
      Navigator.of(context).pushReplacement(
        PageRouteBuilder(
          pageBuilder: (context, animation, secondaryAnimation) =>
              privacyAccepted ? const HomeScreen() : const PrivacyScreen(),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return FadeTransition(opacity: animation, child: child);
          },
          transitionDuration: const Duration(milliseconds: 500),
        ),
      );
    } catch (e) {
      if (kDebugMode) debugPrint('❌ Error in _startLoading: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao carregar: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    }
  }

  @override
  void dispose() {
    _rotationController.dispose();
    _fadeController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dots = '.' * _dotCount;

    return FadeTransition(
      opacity: _fadeAnimation,
      child: Scaffold(
        backgroundColor: AppColors.darkBlue,
        body: Container(
          decoration: const BoxDecoration(
            gradient: RadialGradient(
              center: Alignment.center,
              radius: 1.2,
              colors: [
                Color(0xFF0D2040),
                Color(0xFF0A1A2F),
                Color(0xFF060E1A),
              ],
            ),
          ),
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Spacer(flex: 2),

                // App Logo
                ScaleTransition(
                  scale: _pulseAnimation,
                  child: Container(
                    width: 140,
                    height: 140,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.accent.withOpacity(0.3),
                          blurRadius: 30,
                          spreadRadius: 5,
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(24),
                      child: Image.asset(
                        'assets/icons/app_icon.png',
                        fit: BoxFit.cover,
                        errorBuilder: (ctx, _, __) => Container(
                          color: AppColors.darkGray,
                          child: const Center(
                            child: Text(
                              'ANGO\nMOVIE',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: AppColors.accent,
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 2,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                // App Name
                const Text(
                  'ANGOMOVIE',
                  style: TextStyle(
                    color: AppColors.accent,
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 4,
                  ),
                ),

                const Text(
                  'IPTV',
                  style: TextStyle(
                    color: AppColors.textMuted,
                    fontSize: 14,
                    letterSpacing: 8,
                  ),
                ),

                const Spacer(),

                // Loading Indicator
                RotationTransition(
                  turns: _rotationController,
                  child: Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: AppColors.accent,
                        width: 3,
                      ),
                    ),
                    child: Container(
                      margin: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: AppColors.mediumGray,
                          width: 1,
                        ),
                      ),
                      child: Align(
                        alignment: Alignment.topCenter,
                        child: Container(
                          width: 8,
                          height: 8,
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            color: AppColors.accent,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 24),

                // Loading Text
                Text(
                  'Carregando experiência$dots',
                  style: const TextStyle(
                    color: AppColors.lightGray,
                    fontSize: 16,
                  ),
                ),

                const SizedBox(height: 8),

                // Secondary Text
                AnimatedOpacity(
                  opacity: _showSecondaryText ? 1.0 : 0.0,
                  duration: const Duration(milliseconds: 500),
                  child: const Text(
                    'Preparando canais ao vivo...',
                    style: TextStyle(
                      color: AppColors.textMuted,
                      fontSize: 12,
                    ),
                  ),
                ),

                const Spacer(),

                // Version
                Padding(
                  padding: const EdgeInsets.only(bottom: 32),
                  child: Text(
                    'v1.2.0',
                    style: TextStyle(
                      color: AppColors.textMuted.withOpacity(0.5),
                      fontSize: 11,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
