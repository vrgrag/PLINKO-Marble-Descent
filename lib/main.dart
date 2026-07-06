import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'screens/splash_screen.dart';
import 'theme.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: AppColors.deepBlack,
      systemNavigationBarIconBrightness: Brightness.light,
    ),
  );
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  runApp(const MarbleDescentApp());
}

class MarbleDescentApp extends StatelessWidget {
  const MarbleDescentApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Marble Descent',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: AppColors.deepBlack,
        colorScheme: ColorScheme.fromSeed(
          seedColor: AppColors.neonPurple,
          brightness: Brightness.dark,
          surface: AppColors.deepBlack,
        ),
        textTheme: const TextTheme(
          bodyMedium: AppTextStyles.body,
          bodyLarge: AppTextStyles.body,
          titleLarge: AppTextStyles.heading,
          titleMedium: AppTextStyles.heading,
        ),
      ),
      home: const SplashScreen(),
    );
  }
}
