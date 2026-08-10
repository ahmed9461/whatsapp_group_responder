import 'package:flutter/material.dart';
import 'core/app_controller.dart';
import 'core/theme.dart';
import 'features/enrollment/enrollment_page.dart';
import 'features/shell/home_shell.dart';

class ResponderApp extends StatelessWidget {
  const ResponderApp({super.key, required this.controller});

  final AppController controller;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        return MaterialApp(
          title: 'ردود واتساب',
          debugShowCheckedModeBanner: false,
          theme: buildAppTheme(Brightness.light),
          darkTheme: buildAppTheme(Brightness.dark),
          themeMode: controller.themeMode,
          builder: (context, child) => Directionality(
            textDirection: TextDirection.rtl,
            child: child ?? const SizedBox.shrink(),
          ),
          home: controller.isLinked
              ? HomeShell(controller: controller)
              : EnrollmentPage(controller: controller),
        );
      },
    );
  }
}
