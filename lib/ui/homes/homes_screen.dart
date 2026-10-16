import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:fridgo/domain/home.dart';
import 'package:fridgo/l10n/app_localizations.dart';
import 'package:fridgo/ui/core/app_theme.dart';
import 'package:fridgo/ui/core/emoji.dart';
import 'package:fridgo/ui/core/empty_state.dart';
import 'package:fridgo/ui/homes/create_home_sheet.dart';
import 'package:fridgo/ui/homes/homes_view_model.dart';

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
            child: _AppearAnimation(child: _HomeCard(home: home)),
          ),
      ],
    );
  }
}

class _AppearAnimation extends StatelessWidget {
  const new({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Durations.medium2,
      curve: Easing.emphasizedDecelerate,
      builder: (context, progress, child) => Opacity(
        opacity: progress,
        child: Transform.translate(
          offset: Offset(0, (1 - progress) * Spacing.l),
          child: child,
        ),
      ),
      child: child,
    );
  }
}

class _HomeCard extends StatelessWidget {
  const new({required this.home});

  final Home home;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(Spacing.m),
        child: Row(
          spacing: Spacing.m,
          children: [
            Container(
              width: Sizes.icon,
              height: Sizes.icon,
              padding: const EdgeInsets.all(Spacing.s),
              decoration: BoxDecoration(
                color: theme.colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(Corners.small),
              ),
              child: SvgPicture.asset(Emoji.house, excludeFromSemantics: true),
            ),
            Expanded(
              child: Text(home.name, style: theme.textTheme.titleMedium),
            ),
          ],
        ),
      ),
    );
  }
}
