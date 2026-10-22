import 'package:flutter/material.dart';
import 'main_scaffold.dart';

/// Legacy entry point that delegates to the comprehensive [MainScaffold].
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return MainScaffold(
      currentThemeMode: ThemeMode.light,
      onThemeModeChanged: (_) {},
    );
  }
}
