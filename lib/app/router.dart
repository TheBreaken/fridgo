import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fridgo/ui/add_stock_item/add_stock_item_screen.dart';
import 'package:fridgo/ui/homes/homes_screen.dart';
import 'package:fridgo/ui/stock_overview/stock_overview_screen.dart';
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
            path: 'homes/:homeId',
            builder: (context, state) =>
                StockOverviewScreen(homeId: state.pathParameters['homeId']!),
            routes: [
              GoRoute(
                path: 'storage-locations',
                builder: (context, state) => StorageLocationsScreen(
                  homeId: state.pathParameters['homeId']!,
                ),
              ),
              GoRoute(
                path: 'stock-items/new',
                builder: (context, state) =>
                    AddStockItemScreen(homeId: state.pathParameters['homeId']!),
              ),
            ],
          ),
        ],
      ),
    ],
  );
  ref.onDispose(router.dispose);
  return router;
});
