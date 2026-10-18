import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fridgo/domain/stock_item.dart';
import 'package:fridgo/l10n/app_localizations.dart';
import 'package:fridgo/ui/core/app_theme.dart';
import 'package:fridgo/ui/core/product_thumbnail.dart';
import 'package:fridgo/ui/core/stock_unit_display.dart';
import 'package:fridgo/ui/stock_overview/consume_stock_item_view_model.dart';

Future<void> showConsumeStockItemSheet(
  BuildContext context,
  StockItemDetails details,
) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (context) => ConsumeStockItemSheet(details: details),
  );
}

class ConsumeStockItemSheet extends ConsumerStatefulWidget {
  const new({required this.details, super.key});

  final StockItemDetails details;

  @override
  ConsumerState<ConsumeStockItemSheet> createState() =>
      _ConsumeStockItemSheetState();
}

class _ConsumeStockItemSheetState extends ConsumerState<ConsumeStockItemSheet> {
  final _formKey = GlobalKey<FormState>();
  late final _consumedController = TextEditingController(
    text: _viewModel.initialConsumedInput(_stockItem.unit),
  );
  bool _isSaving = false;

  ConsumeStockItemViewModel get _viewModel =>
      ref.read(consumeStockItemViewModelProvider);

  StockItem get _stockItem => widget.details.stockItem;

  @override
  void dispose() {
    _consumedController.dispose();
    super.dispose();
  }

  Future<void> _consumePartly() async {
    if (_isSaving || !_formKey.currentState!.validate()) return;
    final l10n = AppLocalizations.of(context);
    final consumed = _viewModel.parseQuantity(_consumedController.text);
    await _finish(
      _viewModel.consume(_stockItem, _consumedController.text),
      l10n.stockItemConsumedPartly(
        widget.details.product.name,
        _stockItem.unit.formatQuantity(consumed, l10n),
      ),
    );
  }

  Future<void> _consumeCompletely() async {
    if (_isSaving) return;
    final l10n = AppLocalizations.of(context);
    await _finish(
      _viewModel.consumeCompletely(_stockItem),
      l10n.stockItemConsumedCompletely(widget.details.product.name),
    );
  }

  Future<void> _finish(Future<void> consumption, String message) async {
    setState(() => _isSaving = true);
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final viewModel = _viewModel;
    final previous = _stockItem;
    await consumption;
    if (mounted) Navigator.of(context).pop();
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          action: SnackBarAction(
            label: l10n.undo,
            onPressed: () => viewModel.undo(previous),
          ),
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final StockItemDetails(:stockItem, :product) = widget.details;
    return Padding(
      padding: EdgeInsets.fromLTRB(
        Spacing.l,
        0,
        Spacing.l,
        Spacing.l + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: Form(
        key: _formKey,
        autovalidateMode: AutovalidateMode.onUserInteractionIfError,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: Spacing.l,
          children: [
            Row(
              spacing: Spacing.m,
              children: [
                ProductThumbnail(imagePath: product.imagePath),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    spacing: Spacing.xs,
                    children: [
                      Text(
                        l10n.consumeStockItemTitle(product.name),
                        style: theme.textTheme.titleLarge,
                      ),
                      Text(
                        l10n.consumeStockItemAvailable(
                          stockItem.unit.formatQuantity(
                            stockItem.quantity,
                            l10n,
                          ),
                        ),
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            TextFormField(
              controller: _consumedController,
              autofocus: _consumedController.text.isEmpty,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              textInputAction: TextInputAction.done,
              decoration: InputDecoration(
                labelText: l10n.consumedQuantityLabel,
                suffixText: stockItem.unit.label(l10n),
              ),
              validator: (consumed) =>
                  _viewModel.isValidQuantity(consumed ?? '')
                  ? null
                  : l10n.stockItemQuantityInvalid,
              onFieldSubmitted: (_) => _consumePartly(),
            ),
            Row(
              spacing: Spacing.m,
              children: [
                Expanded(
                  child: FilledButton.tonal(
                    onPressed: _isSaving ? null : _consumeCompletely,
                    child: Text(l10n.consumeCompletely),
                  ),
                ),
                Expanded(
                  child: FilledButton(
                    onPressed: _isSaving ? null : _consumePartly,
                    child: Text(l10n.consumePartly),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
