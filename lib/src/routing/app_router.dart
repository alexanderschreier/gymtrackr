import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../presentation/home/home_scaffold.dart';
import '../presentation/workout/workout_session_page.dart';
import '../presentation/exercises/exercises_page.dart';
import '../presentation/plans/plans_page.dart';
import '../presentation/history/history_page.dart';
import '../presentation/history/workout_detail_page.dart';


GoRouter createRouter() {
  return GoRouter(
    initialLocation: '/',
    routes: <RouteBase>[
      GoRoute(
        path: '/',
        name: 'home',
        pageBuilder: (context, state) => const NoTransitionPage(
          child: HomeScaffold(),
        ),
      ),
      GoRoute(
        path: '/workout/:id',
        name: 'workout',
        pageBuilder: (context, state) {
          final id = int.parse(state.pathParameters['id']!);
          return MaterialPage(child: WorkoutSessionPage(workoutId: id));
        },
      ),
      GoRoute(
        path: '/exercises',
        name: 'exercises',
        builder: (context, state) => const ExercisesPage(),
      ),
      GoRoute(
        path: '/plans',
        name: 'plans',
        builder: (context, state) => const PlansPage(),
      ),
      GoRoute(
        path: '/history',
        name: 'history',
        builder: (context, state) => const HistoryPage(),
      ),
      GoRoute(
        path: '/history/:id',
        name: 'workoutDetail',
        pageBuilder: (context, state) {
          final id = int.parse(state.pathParameters['id']!);
          return MaterialPage(child: WorkoutDetailPage(workoutId: id));
        },
      ),
    ],
  );
}
