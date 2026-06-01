import 'package:flutter/material.dart';

Route<T> slideRoute<T>(Widget page, RouteSettings settings) {
  return PageRouteBuilder<T>(
    settings: settings,
    pageBuilder: (_, __, ___) => page,
    transitionsBuilder: (_, animation, __, child) {
      final slide = Tween<Offset>(
        begin: const Offset(0.08, 0),
        end: Offset.zero,
      ).chain(CurveTween(curve: Curves.easeOutCubic)).animate(animation);
      final fade = CurvedAnimation(parent: animation, curve: Curves.easeOut);

      return SlideTransition(
        position: slide,
        child: FadeTransition(opacity: fade, child: child),
      );
    },
    transitionDuration: const Duration(milliseconds: 240),
  );
}

Route<T> fadeRoute<T>(Widget page, RouteSettings settings) {
  return PageRouteBuilder<T>(
    settings: settings,
    pageBuilder: (_, __, ___) => page,
    transitionsBuilder: (_, animation, __, child) =>
        FadeTransition(opacity: animation, child: child),
    transitionDuration: const Duration(milliseconds: 180),
  );
}