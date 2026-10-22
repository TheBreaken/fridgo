import 'package:flutter/material.dart';
import 'package:fridgo/domain/product.dart';
import 'package:fridgo/l10n/app_localizations.dart';
import 'package:fridgo/ui/core/app_theme.dart';
import 'package:fridgo/ui/core/product_thumbnail.dart';

class SelectedProductCard extends StatelessWidget {
  const new({
    required this.product,
    required this.onEdit,
    required this.onCleared,
    super.key,
  });

  final Product product;
  final VoidCallback onEdit;
  final VoidCallback onCleared;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(Spacing.m),
        child: Row(
          spacing: Spacing.m,
          children: [
            ProductThumbnail(imagePath: product.imagePath),
            Expanded(
              child: Text(product.name, style: theme.textTheme.titleMedium),
            ),
            IconButton(
              onPressed: onEdit,
              tooltip: l10n.editProduct,
              icon: const Icon(Icons.edit_rounded),
            ),
            IconButton(
              onPressed: onCleared,
              tooltip: l10n.clearSelectedProduct,
              icon: const Icon(Icons.close_rounded),
            ),
          ],
        ),
      ),
    );
  }
}
