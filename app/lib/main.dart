import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/theme/app_theme.dart';
import 'core/routing/app_router.dart';

void main() {
  runApp(
    const ProviderScope(
      child: AiStudyCompanionApp(),
    ),
  );
}

class AiStudyCompanionApp extends ConsumerWidget {
  const AiStudyCompanionApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);

    return MaterialApp.router(
      title: 'AI Study Companion',
      theme: AppTheme.lightTheme,
      routerConfig: router,
      debugShowCheckedModeBanner: false,
    );
  }
}
