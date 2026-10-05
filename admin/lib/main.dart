import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:google_fonts/google_fonts.dart';

import 'router/app_router.dart';
import 'services/supabase_service.dart';
import 'theme/app_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Load environment variables
  await dotenv.load(fileName: ".env");
  
  // Initialize Supabase
  await SupabaseService.initialize();

  // Pre-load fonts to prevent jumping
  await Future.wait([
    GoogleFonts.pendingFonts([
      GoogleFonts.spaceGrotesk(),
      GoogleFonts.inter(),
    ]),
  ]);

  runApp(const PortfolioAdminApp());
}

class PortfolioAdminApp extends StatelessWidget {
  const PortfolioAdminApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'Portfolio Admin',
      theme: AppTheme.lightTheme,
      routerConfig: router,
      debugShowCheckedModeBanner: false,
    );
  }
}
