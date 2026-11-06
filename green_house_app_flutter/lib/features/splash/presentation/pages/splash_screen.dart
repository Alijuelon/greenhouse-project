import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:audioplayers/audioplayers.dart';
import 'dart:math' as math;

class SplashScreen extends StatefulWidget {
  final Widget nextScreen;

  const SplashScreen({super.key, required this.nextScreen});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  late AnimationController _logoController;
  late AnimationController _fadeController;
  late AnimationController _ringController;
  late AnimationController _bgShiftController;
  late Animation<double> _logoScale;
  late Animation<double> _logoOpacity;
  late Animation<double> _textOpacity;
  late Animation<Offset> _textSlide;
  late Animation<double> _ringScale;
  late Animation<double> _ringOpacity;
  late Animation<double> _bgShift;
  late AudioPlayer _audioPlayer;

  @override
  void initState() {
    super.initState();

    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
      ),
    );

    _audioPlayer = AudioPlayer();

    // Background color shift animation
    _bgShiftController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3000),
    )..repeat(reverse: true);
    _bgShift = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _bgShiftController, curve: Curves.easeInOut),
    );

    // Logo animation: scale + opacity
    _logoController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _logoScale = Tween<double>(begin: 0.2, end: 1.0).animate(
      CurvedAnimation(parent: _logoController, curve: Curves.elasticOut),
    );
    _logoOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _logoController,
        curve: const Interval(0.0, 0.5, curve: Curves.easeIn),
      ),
    );

    // Ring pulse animation
    _ringController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    );
    _ringScale = Tween<double>(begin: 0.5, end: 2.2).animate(
      CurvedAnimation(parent: _ringController, curve: Curves.easeOut),
    );
    _ringOpacity = Tween<double>(begin: 0.7, end: 0.0).animate(
      CurvedAnimation(parent: _ringController, curve: Curves.easeOut),
    );

    // Text fade animation
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _textOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _fadeController, curve: Curves.easeIn),
    );
    _textSlide = Tween<Offset>(
      begin: const Offset(0, 0.4),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(parent: _fadeController, curve: Curves.easeOutCubic),
    );

    _startAnimations();
  }

  Future<void> _startAnimations() async {
    await Future.delayed(const Duration(milliseconds: 300));

    try {
      await _audioPlayer.play(AssetSource('audio/splash_chime.wav'));
    } catch (_) {}

    _logoController.forward();
    _ringController.forward();

    await Future.delayed(const Duration(milliseconds: 600));
    _fadeController.forward();

    await Future.delayed(const Duration(milliseconds: 2400));
    if (mounted) {
      SystemChrome.setSystemUIOverlayStyle(
        const SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.dark,
        ),
      );
      Navigator.of(context).pushReplacement(
        PageRouteBuilder(
          pageBuilder: (context, animation, secondaryAnimation) => widget.nextScreen,
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return FadeTransition(opacity: animation, child: child);
          },
          transitionDuration: const Duration(milliseconds: 700),
        ),
      );
    }
  }

  @override
  void dispose() {
    _logoController.dispose();
    _fadeController.dispose();
    _ringController.dispose();
    _bgShiftController.dispose();
    _audioPlayer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;

    return Scaffold(
      body: AnimatedBuilder(
        animation: _bgShift,
        builder: (context, child) {
          return Container(
            width: double.infinity,
            height: double.infinity,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color.lerp(
                    const Color(0xFF0D47A1),
                    const Color(0xFF1A237E),
                    _bgShift.value,
                  )!,
                  Color.lerp(
                    const Color(0xFF1565C0),
                    const Color(0xFF283593),
                    _bgShift.value,
                  )!,
                  Color.lerp(
                    const Color(0xFF1B5E20),
                    const Color(0xFF2E7D32),
                    _bgShift.value,
                  )!,
                  Color.lerp(
                    const Color(0xFF004D40),
                    const Color(0xFF00695C),
                    _bgShift.value,
                  )!,
                ],
                stops: const [0.0, 0.3, 0.65, 1.0],
              ),
            ),
            child: child,
          );
        },
        child: Stack(
          alignment: Alignment.center,
          children: [
            // ── Floating orbs background ──
            Positioned(
              top: screenSize.height * 0.08,
              left: -60,
              child: Container(
                width: 220,
                height: 220,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      Colors.cyan.withValues(alpha: 0.2),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
            Positioned(
              top: screenSize.height * 0.15,
              right: -40,
              child: Container(
                width: 160,
                height: 160,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      Colors.white.withValues(alpha: 0.12),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
            Positioned(
              bottom: screenSize.height * 0.12,
              right: -50,
              child: Container(
                width: 200,
                height: 200,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      const Color(0xFF69F0AE).withValues(alpha: 0.18),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
            Positioned(
              bottom: screenSize.height * 0.2,
              left: -30,
              child: Container(
                width: 130,
                height: 130,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      Colors.purple.withValues(alpha: 0.15),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),

            // ── Background dots ──
            ..._buildBackgroundDots(),

            // ── Pulsing colored ring ──
            AnimatedBuilder(
              animation: _ringController,
              builder: (context, child) {
                return Transform.scale(
                  scale: _ringScale.value,
                  child: Opacity(
                    opacity: _ringOpacity.value,
                    child: Container(
                      width: 160,
                      height: 160,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: const Color(0xFF69F0AE).withValues(alpha: 0.5),
                          width: 2,
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),

            // ── Main content ──
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Logo with 3D shadow container
                AnimatedBuilder(
                  animation: _logoController,
                  builder: (context, child) {
                    return Opacity(
                      opacity: _logoOpacity.value,
                      child: Transform.scale(
                        scale: _logoScale.value,
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            // 3D shadow layer
                            Container(
                              width: 128,
                              height: 128,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(34),
                                boxShadow: [
                                  BoxShadow(
                                    color: const Color(0xFF69F0AE).withValues(alpha: 0.4),
                                    blurRadius: 40,
                                    spreadRadius: 4,
                                    offset: const Offset(0, 8),
                                  ),
                                  BoxShadow(
                                    color: Colors.cyan.withValues(alpha: 0.3),
                                    blurRadius: 60,
                                    spreadRadius: 0,
                                    offset: const Offset(-8, -4),
                                  ),
                                  BoxShadow(
                                    color: Colors.blue.withValues(alpha: 0.25),
                                    blurRadius: 30,
                                    spreadRadius: 2,
                                    offset: const Offset(8, 4),
                                  ),
                                ],
                              ),
                            ),
                            // White container with logo
                            Container(
                              width: 120,
                              height: 120,
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(30),
                                border: Border.all(
                                  color: Colors.white.withValues(alpha: 0.8),
                                  width: 2,
                                ),
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(28),
                                child: Padding(
                                  padding: const EdgeInsets.all(10),
                                  child: Image.asset(
                                    'assets/images/greenhouse_logo.png',
                                    fit: BoxFit.contain,
                                    errorBuilder: (context, error, stackTrace) => const Icon(
                                      Icons.eco,
                                      color: Color(0xFF2E7D32),
                                      size: 56,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),

                const SizedBox(height: 36),

                // App name + subtitle
                SlideTransition(
                  position: _textSlide,
                  child: FadeTransition(
                    opacity: _textOpacity,
                    child: Column(
                      children: [
                        // Title with gradient shimmer effect
                        ShaderMask(
                          shaderCallback: (bounds) => const LinearGradient(
                            colors: [
                              Color(0xFFFFFFFF),
                              Color(0xFF69F0AE),
                              Color(0xFF4FC3F7),
                              Color(0xFFFFFFFF),
                            ],
                            stops: [0.0, 0.35, 0.65, 1.0],
                          ).createShader(bounds),
                          child: const Text(
                            'Green House App',
                            style: TextStyle(
                              fontSize: 30,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                              letterSpacing: 1.2,
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          'Smart Farming • IoT • AI Powered',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w400,
                            color: Colors.white.withValues(alpha: 0.75),
                            letterSpacing: 2.0,
                          ),
                        ),
                        const SizedBox(height: 20),
                        // Sensor badges
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            _SensorBadge(
                                icon: Icons.thermostat,
                                label: 'Suhu',
                                color: const Color(0xFFFFB74D)),
                            const SizedBox(width: 8),
                            _SensorBadge(
                                icon: Icons.water_drop,
                                label: 'pH',
                                color: const Color(0xFF4FC3F7)),
                            const SizedBox(width: 8),
                            _SensorBadge(
                                icon: Icons.spa,
                                label: 'NPK',
                                color: const Color(0xFF69F0AE)),
                            const SizedBox(width: 8),
                            _SensorBadge(
                                icon: Icons.wifi,
                                label: 'IoT',
                                color: const Color(0xFFCE93D8)),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),

            // Bottom version
            Positioned(
              bottom: 48,
              child: FadeTransition(
                opacity: _textOpacity,
                child: Text(
                  'v1.0.0 • AgriSense',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.white.withValues(alpha: 0.45),
                    letterSpacing: 1.5,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildBackgroundDots() {
    final random = math.Random(42);
    return List.generate(24, (index) {
      final left = random.nextDouble() * 400;
      final top = random.nextDouble() * 900;
      final size = 1.5 + random.nextDouble() * 3.5;
      final opacity = 0.04 + random.nextDouble() * 0.12;

      return Positioned(
        left: left,
        top: top,
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: opacity),
            shape: BoxShape.circle,
          ),
        ),
      );
    });
  }
}

class _SensorBadge extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;

  const _SensorBadge({
    required this.icon,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(9999),
        border: Border.all(color: color.withValues(alpha: 0.4), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: color,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
