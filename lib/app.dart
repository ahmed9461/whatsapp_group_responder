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
  late bool _isLinked;
  late ThemeMode _themeMode;

  @override
  void initState() {
    super.initState();
    _isLinked = widget.controller.isLinked;
    _themeMode = widget.controller.themeMode;
    widget.controller.addListener(_handleShellState);
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didUpdateWidget(covariant ResponderApp oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (identical(oldWidget.controller, widget.controller)) return;
    oldWidget.controller.removeListener(_handleShellState);
    _isLinked = widget.controller.isLinked;
    _themeMode = widget.controller.themeMode;
    widget.controller.addListener(_handleShellState);
  }

  void _handleShellState() {
    final linked = widget.controller.isLinked;
    final theme = widget.controller.themeMode;
    if (linked == _isLinked && theme == _themeMode) return;
    if (!mounted) return;
    setState(() {
      _isLinked = linked;
      _themeMode = theme;
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    widget.controller.removeListener(_handleShellState);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(widget.controller.handleAppResumed());
    } else if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden ||
        state == AppLifecycleState.detached) {
      unawaited(widget.controller.handleAppPaused());
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ردود واتساب',
      debugShowCheckedModeBanner: false,
      theme: buildAppTheme(Brightness.light),
      darkTheme: buildAppTheme(Brightness.dark),
      themeMode: _themeMode,
      builder: (context, child) => Directionality(
        textDirection: TextDirection.rtl,
        child: child ?? const SizedBox.shrink(),
      ),
      home: _isLinked
          ? HomeShell(controller: widget.controller)
          : EnrollmentPage(controller: widget.controller),
    );
  }
}
