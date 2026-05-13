import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'theme/app_theme.dart';
import 'screens/home_screen.dart';
import 'screens/onboarding_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();
  final onboardingDone = prefs.getBool('onboarding_complete') ?? false;
  runApp(MinistryOfTruthApp(showOnboarding: !onboardingDone));
}

class MinistryOfTruthApp extends StatelessWidget {
  final bool showOnboarding;
  const MinistryOfTruthApp({super.key, required this.showOnboarding});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Ministry of Truth',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      home: showOnboarding ? const OnboardingScreen() : const HomeScreen(),
    );
  }
}
