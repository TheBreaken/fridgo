import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fridgo/domain/home.dart';
import 'package:fridgo/l10n/app_localizations.dart';
import 'package:fridgo/ui/core/app_theme.dart';
import 'package:fridgo/ui/core/appear_animation.dart';
import 'package:fridgo/ui/core/delete_confirmation.dart';
import 'package:fridgo/ui/core/emoji.dart';
import 'package:fridgo/ui/core/emoji_tile.dart';
import 'package:fridgo/ui/core/empty_state.dart';
import 'package:fridgo/ui/homes/create_home_sheet.dart';
import 'package:fridgo/ui/homes/homes_view_model.dart';
import 'package:go_router/go_router.dart';

class HomesScreen extends ConsumerWidget {
  const new({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final homes = ref.watch(homesViewModelProvider);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.homesTitle)),
      body: AnimatedSwitcher(
        duration: Durations.medium2,
        child: switch (homes) {
          AsyncData(value: []) => const _EmptyHomes(),
          AsyncData(:final value) => _HomeList(homes: value),
          AsyncError(:final error, :final stackTrace) =>
            Error.throwWithStackTrace(error, stackTrace),
          _ => const SizedBox.shrink(),
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => showCreateHomeSheet(context),
        tooltip: l10n.addHome,
        child: const Icon(Icons.add_rounded),
      ),
    );
  }
}

class _EmptyHomes extends StatelessWidget {
  const new();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return ListView(
      padding: const EdgeInsets.all(Spacing.l),
      children: [
        EmptyState(
          emoji: Emoji.house,
          title: l10n.homesEmptyTitle,
          message: l10n.homesEmptyMessage,
          action: FilledButton(
            onPressed: () => showCreateHomeSheet(context),
            child: Text(l10n.addHome),
          ),
        ),
      ],
    );
  }
}

class _HomeList extends StatelessWidget {
  const new({required this.homes});

  final List<Home> homes;

  @override
  Widget build(BuildContext context) {
    // A plain ListView matches keyed children to their elements, so only a
    // newly created home plays the entry animation.
    return ListView(
      padding: const EdgeInsets.all(Spacing.l),
      children: [
        for (final home in homes)
          Padding(
            key: ValueKey(home.id),
            padding: const EdgeInsets.only(bottom: Spacing.m),
            child: AppearAnimation(child: _HomeCard(home: home)),
          ),
      ],
    );
  }
}

void openHome(BuildContext context, WidgetRef ref, String homeId) {
  unawaited(ref.read(homesViewModelProvider.notifier).selectHome(homeId));
  context.go('/homes/$homeId');
}

class _HomeCard extends ConsumerWidget {
  const new({required this.home});

  final Home home;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => openHome(context, ref, home.id),
        child: Padding(
          padding: const EdgeInsets.all(Spacing.m),
          child: Row(
            spacing: Spacing.m,
            children: [
              const EmojiTile(emoji: Emoji.house),
              Expanded(
                child: Text(home.name, style: theme.textTheme.titleMedium),
              ),
              _HomeMenu(home: home),
            ],
          ),
        ),
      ),
    );
  }
}

enum _HomeAction { rename, delete }

class _HomeMenu extends ConsumerWidget {
  const new({required this.home});

  final Home home;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    return PopupMenuButton<_HomeAction>(
      tooltip: l10n.moreActions,
      icon: const Icon(Icons.more_vert_rounded),
      onSelected: (action) => switch (action) {
        _HomeAction.rename => showCreateHomeSheet(context, home: home),
        _HomeAction.delete => _deleteHome(context, ref),
      },
      itemBuilder: (context) => [
        PopupMenuItem(
          value: _HomeAction.rename,
          child: ListTile(
            leading: const Icon(Icons.edit_rounded),
            title: Text(l10n.renameHome),
          ),
        ),
        PopupMenuItem(
          value: _HomeAction.delete,
          child: ListTile(
            leading: const Icon(Icons.delete_rounded),
            title: Text(l10n.delete),
          ),
        ),
      ],
    );
  }

  Future<void> _deleteHome(BuildContext context, WidgetRef ref) async {
    final l10n = AppLocalizations.of(context);
    final viewModel = ref.read(homesViewModelProvider.notifier);
    final stockItemCount = await viewModel.countStockItems(home.id);
    if (!context.mounted) return;
    final confirmed = await confirmDelete(
      context,
      title: l10n.deleteHomeTitle(home.name),
      message: l10n.deleteHomeMessage(stockItemCount),
    );
    if (!confirmed || !context.mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    await viewModel.deleteHome(home.id);
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(l10n.homeDeleted(home.name))));
  }
}
