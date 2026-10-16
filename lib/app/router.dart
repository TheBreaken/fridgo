import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fridgo/ui/homes/homes_screen.dart';
import 'package:fridgo/ui/storage_locations/storage_locations_screen.dart';
import 'package:go_router/go_router.dart';

final routerProvider = Provider<GoRouter>((ref) {
  final router = GoRouter(
    routes: [
      GoRoute(
        path: '/',
        builder: (context, state) => const HomesScreen(),
        routes: [
          GoRoute(
            path: 'homes/:homeId/storage-locations',
            builder: (context, state) =>
                StorageLocationsScreen(homeId: state.pathParameters['homeId']!),
          ),
        ],
      ),
    ],
  );
  ref.onDispose(router.dispose);
  return router;
});
