import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fridgo/l10n/app_localizations.dart';
import 'package:fridgo/ui/core/app_theme.dart';
import 'package:fridgo/ui/core/emoji.dart';
import 'package:fridgo/ui/core/emoji_tile.dart';
import 'package:fridgo/ui/homes/homes_screen.dart';
import 'package:fridgo/ui/homes/homes_view_model.dart';

Future<void> showSwitchHomeSheet(BuildContext context, String currentHomeId) {
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (context) => SwitchHomeSheet(currentHomeId: currentHomeId),
  );
}

class SwitchHomeSheet extends ConsumerWidget {
  const new({required this.currentHomeId, super.key});

  final String currentHomeId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final homes = ref.watch(homesViewModelProvider).value ?? [];
    return ListView(
      shrinkWrap: true,
      padding: EdgeInsets.fromLTRB(
        Spacing.l,
        0,
        Spacing.l,
        Spacing.l + MediaQuery.paddingOf(context).bottom,
      ),
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            Spacing.l,
            0,
            Spacing.l,
            Spacing.m,
          ),
          child: Text(l10n.switchHome, style: theme.textTheme.titleLarge),
        ),
        for (final home in homes)
          ListTile(
            leading: const EmojiTile(emoji: Emoji.house),
            title: Text(home.name, style: theme.textTheme.titleMedium),
            trailing: home.id == currentHomeId
                ? Icon(Icons.check_rounded, color: theme.colorScheme.primary)
                : null,
            selected: home.id == currentHomeId,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(Corners.small),
            ),
            onTap: () {
              Navigator.of(context).pop();
              if (home.id != currentHomeId) openHome(context, ref, home.id);
            },
          ),
      ],
    );
  }
}
