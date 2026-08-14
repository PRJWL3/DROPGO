// Reusable scaffold wrapper enforcing default theme parameters
import 'package:flutter/material.dart';
import '../../core/constants/colors.dart';

class AppScaffold extends StatelessWidget {
  final Widget body;
  final PreferredSizeWidget? appBar;
  final Widget? bottomNavigationBar;
  final Widget? floatingActionButton;
  final bool useSafeArea;

  const AppScaffold({
    super.key,
    required this.body,
    this.appBar,
    this.bottomNavigationBar,
    this.floatingActionButton,
    this.useSafeArea = true,
  });

  @override
  Widget build(BuildContext context) {
    final scaffoldBody = useSafeArea ? SafeArea(child: body) : body;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: appBar,
      body: scaffoldBody,
      bottomNavigationBar: bottomNavigationBar,
      floatingActionButton: floatingActionButton,
    );
  }
}
