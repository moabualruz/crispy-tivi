import 'package:flutter/material.dart';

import '../theme/crispy_animation.dart';
import '../theme/crispy_spacing.dart';
import '../utils/device_form_factor.dart';
import 'crispy_logo.dart';

/// Branded splash screen shown during app startup.
///
/// Displays the app name with a subtle fade-in animation
/// and a progress indicator. Replaces the bare
/// [CircularProgressIndicator] that was shown while
/// settings loaded.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _fadeIn;

  @override
  void initState() {
    super.initState();
    // On Android TV, use a snappy splash (no heavy animations).
    final isTV = DeviceFormFactorService.current.isTV;
    _controller = AnimationController(
      vsync: this,
      duration: isTV ? CrispyAnimation.fast : CrispyAnimation.slow,
    );
    _fadeIn = CurvedAnimation(
      parent: _controller,
      curve: CrispyAnimation.enterCurve,
    );
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark(useMaterial3: true),
      home: Scaffold(
        body: Center(
          child: FadeTransition(
            opacity: _fadeIn,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const CrispyLogo(size: 80),
                const SizedBox(height: CrispySpacing.md),
                Text(
                  'CrispyTivi',
                  style: textTheme.headlineLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(height: CrispySpacing.xxl),
                const SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
