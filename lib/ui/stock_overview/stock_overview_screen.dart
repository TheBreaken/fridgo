import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fridgo/domain/stock_item.dart';
import 'package:fridgo/l10n/app_localizations.dart';
import 'package:fridgo/ui/core/app_theme.dart';
import 'package:fridgo/ui/core/appear_animation.dart';
import 'package:fridgo/ui/core/emoji.dart';
import 'package:fridgo/ui/core/empty_state.dart';
import 'package:fridgo/ui/stock_overview/stock_item_card.dart';
import 'package:fridgo/ui/stock_overview/stock_overview_view_model.dart';
import 'package:fridgo/ui/storage_locations/create_storage_location_sheet.dart';
import 'package:fridgo/ui/storage_locations/storage_locations_view_model.dart';
import 'package:go_router/go_router.dart';

class StockOverviewScreen extends ConsumerWidget {
  const new({required this.homeId, super.key});

  final String homeId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final home = ref.watch(homeProvider(homeId)).value;
    final storageLocations = ref.watch(
      storageLocationsViewModelProvider(homeId),
    );
    final stockItems = ref.watch(stockOverviewProvider(homeId));
    final hasStorageLocations = storageLocations.value?.isNotEmpty ?? false;
    return Scaffold(
      appBar: AppBar(
        title: Text(home?.name ?? ''),
        actions: [
          IconButton(
            onPressed: () => context.go('/homes/$homeId/storage-locations'),
            tooltip: l10n.showStorageLocations,
            icon: const Icon(Icons.kitchen_rounded),
          ),
        ],
      ),
      body: AnimatedSwitcher(
        duration: Durations.medium2,
        child: switch ((storageLocations, stockItems)) {
          (AsyncError(:final error, :final stackTrace), _) ||
          (
            _,
            AsyncError(:final error, :final stackTrace),
          ) => Error.throwWithStackTrace(error, stackTrace),
          (AsyncData(value: []), _) => _NoStorageLocation(homeId: homeId),
          (AsyncData(), AsyncData(value: [])) => _EmptyStock(homeId: homeId),
          (AsyncData(), AsyncData(:final value)) => _StockItemList(
            stockItems: value,
          ),
          _ => const SizedBox.shrink(),
        },
      ),
      floatingActionButton: hasStorageLocations
          ? FloatingActionButton(
              onPressed: () => _openAddStockItem(context, homeId),
              tooltip: l10n.addStockItem,
              child: const Icon(Icons.add_rounded),
            )
          : null,
    );
  }
}

void _openAddStockItem(BuildContext context, String homeId) =>
    context.go('/homes/$homeId/stock-items/new');

class _NoStorageLocation extends StatelessWidget {
  const new({required this.homeId});

  final String homeId;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return ListView(
      padding: const EdgeInsets.all(Spacing.l),
      children: [
        EmptyState(
          emoji: Emoji.jar,
          title: l10n.stockOverviewNoStorageLocationTitle,
          message: l10n.stockOverviewNoStorageLocationMessage,
          action: FilledButton(
            onPressed: () => showCreateStorageLocationSheet(context, homeId),
            child: Text(l10n.addStorageLocation),
          ),
        ),
      ],
    );
  }
}

class _EmptyStock extends StatelessWidget {
  const new({required this.homeId});

  final String homeId;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return ListView(
      padding: const EdgeInsets.all(Spacing.l),
      children: [
        EmptyState(
          emoji: Emoji.carrot,
          title: l10n.stockOverviewEmptyTitle,
          message: l10n.stockOverviewEmptyMessage,
          action: FilledButton(
            onPressed: () => _openAddStockItem(context, homeId),
            child: Text(l10n.addStockItem),
          ),
        ),
      ],
    );
  }
}

class _StockItemList extends ConsumerWidget {
  const new({required this.stockItems});

  final List<StockItemDetails> stockItems;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final today = ref.watch(todayProvider);
    return ListView(
      padding: const EdgeInsets.all(Spacing.l),
      children: [
        for (final details in stockItems)
          Padding(
            key: ValueKey(details.stockItem.id),
            padding: const EdgeInsets.only(bottom: Spacing.m),
            child: AppearAnimation(
              child: StockItemCard(details: details, today: today),
            ),
          ),
      ],
    );
  }
}
