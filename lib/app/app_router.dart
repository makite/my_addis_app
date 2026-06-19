import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:my_addis_app/app/routes.dart';
import 'package:my_addis_app/features/home/presentation/views/home_view.dart';

// ═══ Route Definitions ═══
// New routes are auto-registered below this line by the Riverflow CLI.
// Do not remove the marker comments.

// ══════ RIVERFLOW_ROUTE_IMPORTS ══════

final appRouterProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: Routes.home,
    debugLogDiagnostics: true,
    routes: [
      GoRoute(
        path: Routes.home,
        name: 'home',
        builder: (context, state) => const HomeView(),
      ),
      // ══════ RIVERFLOW_ROUTES ══════
    ],
  );
});
