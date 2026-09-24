import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import 'providers/scanner_provider.dart';
import 'services/camera_service.dart';
import 'services/ml_service.dart';
import 'ui/screens/ar_scanner_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Set immersive warm historical status bar overlay
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: Color(0xFF14110E),
      systemNavigationBarIconBrightness: Brightness.light,
    ),
  );

  final mlService = MLService();
  await mlService.initialize();

  final cameraService = CameraService();
  await cameraService.initialize();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<MLService>.value(value: mlService),
        ChangeNotifierProvider<CameraService>.value(value: cameraService),
        ChangeNotifierProvider<ScannerProvider>(
          create: (_) => ScannerProvider(mlService: mlService),
        ),
      ],
      child: const ARLandmarkApp(),
    ),
  );
}

class ARLandmarkApp extends StatelessWidget {
  const ARLandmarkApp({super.key});

  @override
  Widget build(BuildContext context) {
    // Elegant warm museum & heritage palette
    const primaryGold = Color(0xFFD4AF37);
    const warmSurface = Color(0xFF1E1A16);
    const deepEspresso = Color(0xFF12100E);
    const warmParchment = Color(0xFFF5EBE1);

    final baseTextTheme = ThemeData.dark().textTheme;

    return MaterialApp(
      title: 'Heritage AR - Historical Landmark Explorer',
      debugShowCheckedModeBanner: false,
      themeMode: ThemeMode.dark,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: deepEspresso,
        primaryColor: primaryGold,
        colorScheme: const ColorScheme.dark(
          primary: primaryGold,
          secondary: Color(0xFFE5C158),
          tertiary: Color(0xFFD08A56),
          surface: warmSurface,
          onSurface: warmParchment,
        ),
        textTheme: GoogleFonts.outfitTextTheme(baseTextTheme).copyWith(
          headlineLarge: GoogleFonts.playfairDisplay(
            fontWeight: FontWeight.bold,
            color: warmParchment,
          ),
          headlineMedium: GoogleFonts.playfairDisplay(
            fontWeight: FontWeight.bold,
            color: warmParchment,
          ),
          titleLarge: GoogleFonts.playfairDisplay(
            fontWeight: FontWeight.w700,
            color: primaryGold,
          ),
        ),
        useMaterial3: true,
      ),
      home: const ARScannerScreen(),
    );
  }
}
