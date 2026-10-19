import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fridgo/ui/add_stock_item/add_stock_item_screen.dart';
import 'package:fridgo/ui/homes/homes_screen.dart';
import 'package:fridgo/ui/homes/homes_view_model.dart';
import 'package:fridgo/ui/stock_item_detail/stock_item_detail_screen.dart';
import 'package:fridgo/ui/stock_overview/stock_overview_screen.dart';
import 'package:fridgo/ui/storage_locations/storage_locations_screen.dart';
import 'package:go_router/go_router.dart';

final routerProvider = Provider<GoRouter>((ref) {
  final router = GoRouter(
    initialLocation: '/start',
    routes: [
      GoRoute(
        path: '/start',
        redirect: (context, state) async {
          final homeId = await ref
              .read(homesViewModelProvider.notifier)
              .findStartHomeId();
          return homeId == null ? '/' : '/homes/$homeId';
        },
      ),
      GoRoute(
        path: '/',
        builder: (context, state) => const HomesScreen(),
        routes: [
          GoRoute(
            path: 'homes/:homeId',
            // One page for every home, so switching homes cross-fades inside
            // the page instead of pushing a new one.
            pageBuilder: (context, state) => MaterialPage(
              key: const ValueKey('stock-overview'),
              child: StockOverviewScreen(
                homeId: state.pathParameters['homeId']!,
              ),
            ),
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
              GoRoute(
                path: 'stock-items/:stockItemId',
                builder: (context, state) => StockItemDetailScreen(
                  homeId: state.pathParameters['homeId']!,
                  stockItemId: state.pathParameters['stockItemId']!,
                ),
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
