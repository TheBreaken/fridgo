import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fridgo/domain/storage_location.dart';
import 'package:fridgo/l10n/app_localizations.dart';
import 'package:fridgo/ui/core/app_theme.dart';
import 'package:fridgo/ui/core/appear_animation.dart';
import 'package:fridgo/ui/core/delete_confirmation.dart';
import 'package:fridgo/ui/core/emoji.dart';
import 'package:fridgo/ui/core/emoji_tile.dart';
import 'package:fridgo/ui/core/empty_state.dart';
import 'package:fridgo/ui/core/storage_location_kind_display.dart';
import 'package:fridgo/ui/storage_locations/create_storage_location_sheet.dart';
import 'package:fridgo/ui/storage_locations/storage_locations_view_model.dart';

class StorageLocationsScreen extends ConsumerWidget {
  const new({required this.homeId, super.key});

  final String homeId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final home = ref.watch(homeProvider(homeId)).value;
    final storageLocations = ref.watch(
      storageLocationsViewModelProvider(homeId),
    );
    return Scaffold(
      appBar: AppBar(title: Text(home?.name ?? '')),
      body: AnimatedSwitcher(
        duration: Durations.medium2,
        child: switch (storageLocations) {
          AsyncData(value: []) => _EmptyStorageLocations(homeId: homeId),
          AsyncData(:final value) => _StorageLocationList(
            storageLocations: value,
          ),
          AsyncError(:final error, :final stackTrace) =>
            Error.throwWithStackTrace(error, stackTrace),
          _ => const SizedBox.shrink(),
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => showCreateStorageLocationSheet(context, homeId),
        tooltip: l10n.addStorageLocation,
        child: const Icon(Icons.add_rounded),
      ),
    );
  }
}

class _EmptyStorageLocations extends StatelessWidget {
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
          title: l10n.storageLocationsEmptyTitle,
          message: l10n.storageLocationsEmptyMessage,
          action: FilledButton(
            onPressed: () => showCreateStorageLocationSheet(context, homeId),
            child: Text(l10n.addStorageLocation),
          ),
        ),
      ],
    );
  }
}

class _StorageLocationList extends StatelessWidget {
  const new({required this.storageLocations});

  final List<StorageLocation> storageLocations;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(Spacing.l),
      children: [
        for (final storageLocation in storageLocations)
          Padding(
            key: ValueKey(storageLocation.id),
            padding: const EdgeInsets.only(bottom: Spacing.m),
            child: AppearAnimation(
              child: _StorageLocationCard(storageLocation: storageLocation),
            ),
          ),
      ],
    );
  }
}

class _StorageLocationCard extends StatelessWidget {
  const new({required this.storageLocation});

  final StorageLocation storageLocation;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final kindLabel = storageLocation.kind.label(AppLocalizations.of(context));
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(Spacing.m),
        child: Row(
          spacing: Spacing.m,
          children: [
            EmojiTile(emoji: storageLocation.kind.emoji),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    storageLocation.name,
                    style: theme.textTheme.titleMedium,
                  ),
                  if (kindLabel != storageLocation.name)
                    Text(
                      kindLabel,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                ],
              ),
            ),
            _StorageLocationMenu(storageLocation: storageLocation),
          ],
        ),
      ),
    );
  }
}

enum _StorageLocationAction { edit, delete }

class _StorageLocationMenu extends ConsumerWidget {
  const new({required this.storageLocation});

  final StorageLocation storageLocation;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    return PopupMenuButton<_StorageLocationAction>(
      tooltip: l10n.moreActions,
      icon: const Icon(Icons.more_vert_rounded),
      onSelected: (action) => switch (action) {
        _StorageLocationAction.edit => showCreateStorageLocationSheet(
          context,
          storageLocation.homeId,
          storageLocation: storageLocation,
        ),
        _StorageLocationAction.delete => _deleteStorageLocation(context, ref),
      },
      itemBuilder: (context) => [
        PopupMenuItem(
          value: _StorageLocationAction.edit,
          child: ListTile(
            leading: const Icon(Icons.edit_rounded),
            title: Text(l10n.editStorageLocation),
          ),
        ),
        PopupMenuItem(
          value: _StorageLocationAction.delete,
          child: ListTile(
            leading: const Icon(Icons.delete_rounded),
            title: Text(l10n.delete),
          ),
        ),
      ],
    );
  }

  Future<void> _deleteStorageLocation(
    BuildContext context,
    WidgetRef ref,
  ) async {
    final l10n = AppLocalizations.of(context);
    final viewModel = ref.read(
      storageLocationsViewModelProvider(storageLocation.homeId).notifier,
    );
    final stockItemCount = await viewModel.countStockItems(storageLocation.id);
    if (!context.mounted) return;
    final confirmed = await confirmDelete(
      context,
      title: l10n.deleteStorageLocationTitle(storageLocation.name),
      message: l10n.deleteStorageLocationMessage(stockItemCount),
    );
    if (!confirmed || !context.mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    await viewModel.deleteStorageLocation(storageLocation.id);
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(l10n.storageLocationDeleted(storageLocation.name)),
        ),
      );
  }
}
