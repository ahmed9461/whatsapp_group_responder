import 'dart:async';

import 'package:flutter/material.dart';

import 'core/app_controller.dart';
import 'core/theme.dart';
import 'features/enrollment/enrollment_page.dart';
import 'features/shell/home_shell.dart';

class ResponderApp extends StatefulWidget {
  const ResponderApp({super.key, required this.controller});

  final AppController controller;

  @override
  State<ResponderApp> createState() => _ResponderAppState();
}

class _ResponderAppState extends State<ResponderApp> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(widget.controller.handleAppResumed());
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.controller,
      builder: (context, _) {
        return MaterialApp(
          title: 'ردود واتساب',
          debugShowCheckedModeBanner: false,
          theme: buildAppTheme(Brightness.light),
          darkTheme: buildAppTheme(Brightness.dark),
          themeMode: widget.controller.themeMode,
          builder: (context, child) => Directionality(
            textDirection: TextDirection.rtl,
            child: child ?? const SizedBox.shrink(),
          ),
          home: widget.controller.isLinked
              ? HomeShell(controller: widget.controller)
              : EnrollmentPage(controller: widget.controller),
        );
      },
    );
  }
}
