import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fridgo/ui/start/start_screen.dart';
import 'package:go_router/go_router.dart';

final routerProvider = Provider<GoRouter>((ref) {
  final router = GoRouter(
    routes: [
      GoRoute(path: '/', builder: (context, state) => const StartScreen()),
    ],
  );
  ref.onDispose(router.dispose);
  return router;
});
