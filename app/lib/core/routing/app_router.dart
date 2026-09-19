import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../features/auth/presentation/providers/auth_provider.dart';

// These will be imported later as we create the features
import '../../features/auth/presentation/screens/splash_screen.dart';
import '../../features/auth/presentation/screens/onboarding_screen.dart';
import '../../features/auth/presentation/screens/login_screen.dart';
import '../../features/auth/presentation/screens/register_screen.dart';
import '../../features/dashboard/presentation/screens/home_screen.dart';
import '../../features/chat/presentation/screens/ai_assistant_screen.dart';
import '../../features/study_plan/presentation/screens/study_plan_screen.dart';
import '../../features/focus_timer/presentation/screens/focus_timer_screen.dart';
import '../../features/profile/presentation/screens/profile_screen.dart';
import '../../features/documents/presentation/screens/documents_screen.dart';
import '../../features/dashboard/presentation/screens/timer_screen.dart';
import '../../features/quiz/presentation/screens/quiz_list_screen.dart';
import '../../features/quiz/presentation/screens/quiz_setup_screen.dart';
import '../../features/quiz/presentation/screens/quiz_screen.dart';
import '../../features/flashcard/presentation/screens/flashcard_screen.dart';
import '../../core/layout/main_layout.dart';

final routerProvider = Provider<GoRouter>((ref) {
  final authState = ref.watch(authProvider);

  return GoRouter(
    initialLocation: '/',
    redirect: (context, state) {
      final isAuthRoute = state.matchedLocation == '/login' || state.matchedLocation == '/register' || state.matchedLocation == '/onboarding';
      final isSplash = state.matchedLocation == '/';

      if (authState.status == AuthState.loading) {
        return null;
      }

      if (authState.status == AuthState.unauthenticated || authState.status == AuthState.error) {
        if (isAuthRoute || isSplash) return null;
        return '/login';
      }

      if (authState.status == AuthState.authenticated) {
        if (isAuthRoute || isSplash) return '/home';
      }

      return null;
    },
    routes: [
      GoRoute(
        path: '/',
        builder: (context, state) => const SplashScreen(),
      ),
      GoRoute(
        path: '/onboarding',
        builder: (context, state) => const OnboardingScreen(),
      ),
      GoRoute(
        path: '/login',
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: '/register',
        builder: (context, state) => const RegisterScreen(),
      ),
      GoRoute(
        path: '/home',
        builder: (context, state) => const HomeScreen(),
      ),
      GoRoute(
        path: '/timer',
        builder: (context, state) => const TimerScreen(),
      ),
      GoRoute(
        path: '/quizzes',
        builder: (context, state) => const QuizListScreen(),
      ),
      GoRoute(
        path: '/quiz-setup',
        builder: (context, state) {
          final docId = state.uri.queryParameters['documentId'];
          return QuizSetupScreen(documentId: docId);
        },
      ),
      GoRoute(
        path: '/quiz/:id',
        builder: (context, state) {
          final id = state.pathParameters['id']!;
          return QuizScreen(quizId: id);
        },
      ),
      GoRoute(
        path: '/flashcard/:deckId',
        builder: (context, state) {
          final id = state.pathParameters['deckId']!;
          return FlashcardScreen(deckId: id);
        },
      ),
      GoRoute(
        path: '/chat',
        builder: (context, state) {
          final docId = state.uri.queryParameters['documentId'];
          return AiAssistantScreen(initialDocumentId: docId);
        },
      ),
      GoRoute(
        path: '/study-plan',
        builder: (context, state) => const StudyPlanScreen(),
      ),
      GoRoute(
        path: '/focus-timer',
        builder: (context, state) => const FocusTimerScreen(),
      ),
      GoRoute(
        path: '/profile',
        builder: (context, state) => const MainLayout(
          currentIndex: 4,
          child: ProfileScreen(),
        ),
      ),
      GoRoute(
        path: '/documents',
        builder: (context, state) => const MainLayout(
          currentIndex: 3,
          child: DocumentsScreen(),
        ),
      ),
    ],
  );
});
