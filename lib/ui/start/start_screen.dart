import 'package:flutter/material.dart';
import 'package:fridgo/l10n/app_localizations.dart';
import 'package:fridgo/ui/core/app_theme.dart';
import 'package:fridgo/ui/core/empty_state.dart';
import 'package:fridgo/ui/core/image_placeholder.dart';

class StartScreen extends StatelessWidget {
  const new({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.appTitle)),
      body: ListView(
        padding: const EdgeInsets.all(Spacing.l),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(Spacing.m),
              child: Row(
                spacing: Spacing.m,
                children: [
                  const ImagePlaceholder(),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          l10n.exampleProductName,
                          style: theme.textTheme.titleMedium,
                        ),
                        Text(
                          l10n.exampleProductDetails,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                        Text(
                          l10n.exampleProductBestBefore,
                          style: theme.textTheme.labelLarge?.copyWith(
                            color: theme.colorScheme.primary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: Spacing.l),
          EmptyState(
            title: l10n.exampleEmptyTitle,
            message: l10n.exampleEmptyMessage,
            action: FilledButton(onPressed: () {}, child: Text(l10n.addFood)),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {},
        tooltip: l10n.addFood,
        child: const Icon(Icons.add_rounded),
      ),
    );
  }
}
