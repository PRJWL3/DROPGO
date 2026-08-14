// Core TaxiTown MaterialApp and theme configuration
import 'package:flutter/material.dart';
import 'routes.dart';
import 'theme.dart';

class TaxiTownApp extends StatelessWidget {
  const TaxiTownApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'DROPGO',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      initialRoute: AppRoutes.home,
      routes: AppRoutes.routes,
    );
  }
}
