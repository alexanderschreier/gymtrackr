import 'package:go_router/go_router.dart';
import '../presentation/home/home_scaffold.dart';


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
    ],
  );
}