import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../dashboard/data/repository/biometrics_repository.dart';
import '../dashboard/view/biometrics_dashboard_controller.dart';
import '../dashboard/view/biometrics_dashboard_page.dart';
import '../shared/app_theme.dart';

class BiometricsApp extends StatelessWidget {
  const BiometricsApp({super.key});

  @override
  Widget build(BuildContext context) {
    final repository = BiometricsRepository();
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<BiometricsDashboardController>(
          create: (_) => BiometricsDashboardController(repository: repository)..load(),
        ),
      ],
      child: MaterialApp(
        title: 'Biometrics Dashboard',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light(),
        darkTheme: AppTheme.dark(),
        themeMode: ThemeMode.system,
        home: const BiometricsDashboardPage(),
      ),
    );
  }
}
