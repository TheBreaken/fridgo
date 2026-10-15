import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fridgo/ui/homes/homes_screen.dart';
import 'package:go_router/go_router.dart';

final routerProvider = Provider<GoRouter>((ref) {
  final router = GoRouter(
    routes: [
      GoRoute(path: '/', builder: (context, state) => const HomesScreen()),
    ],
  );
  ref.onDispose(router.dispose);
  return router;
});
