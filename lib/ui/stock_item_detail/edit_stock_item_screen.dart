import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fridgo/domain/calendar_date.dart';
import 'package:fridgo/domain/stock_item.dart';
import 'package:fridgo/l10n/app_localizations.dart';
import 'package:fridgo/ui/core/app_theme.dart';
import 'package:fridgo/ui/core/calendar_date_field.dart';
import 'package:fridgo/ui/core/choice_section.dart';
import 'package:fridgo/ui/core/product_thumbnail.dart';
import 'package:fridgo/ui/core/stock_unit_display.dart';
import 'package:fridgo/ui/stock_item_detail/edit_stock_item_view_model.dart';
import 'package:fridgo/ui/stock_item_detail/stock_item_detail_view_model.dart';
import 'package:go_router/go_router.dart';

class EditStockItemScreen extends ConsumerWidget {
  const new({required this.homeId, required this.stockItemId, super.key});

  final String homeId;
  final String stockItemId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final details = ref.watch(
      stockItemDetailsProvider((homeId: homeId, stockItemId: stockItemId)),
    );
    return Scaffold(
      appBar: AppBar(
        title: Text(AppLocalizations.of(context).editStockItemTitle),
      ),
      body: switch (details) {
        AsyncError(:final error, :final stackTrace) =>
          Error.throwWithStackTrace(error, stackTrace),
        AsyncData(:final value?) => _EditStockItemForm(details: value),
        _ => const SizedBox.shrink(),
      },
    );
  }
}

class _EditStockItemForm extends ConsumerStatefulWidget {
  const new({required this.details});

  final StockItemDetails details;

  @override
  ConsumerState<_EditStockItemForm> createState() => _EditStockItemFormState();
}

class _EditStockItemFormState extends ConsumerState<_EditStockItemForm> {
  final _formKey = GlobalKey<FormState>();
  late final _quantityController = TextEditingController(
    text: formatQuantityNumber(
      _stockItem.quantity,
      AppLocalizations.of(context),
    ),
  );
  late StockUnit _unit = _stockItem.unit;
  late CalendarDate? _bestBeforeDate = _stockItem.bestBeforeDate;
  late CalendarDate? _openedDate = _stockItem.openedDate;
  bool _isSaving = false;

  EditStockItemViewModel get _viewModel =>
      ref.read(editStockItemViewModelProvider);

  StockItem get _stockItem => widget.details.stockItem;

  @override
  void dispose() {
    _quantityController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_isSaving || !_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);
    await _viewModel.save(
      _stockItem.copyWith(
        quantity: _viewModel.parseQuantity(_quantityController.text),
        unit: _unit,
        bestBeforeDate: _bestBeforeDate,
        openedDate: _openedDate,
      ),
    );
    if (mounted) context.pop();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final product = widget.details.product;
    final today = _viewModel.today.toDateTime();
    return Form(
      key: _formKey,
      autovalidateMode: AutovalidateMode.onUserInteractionIfError,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(Spacing.l),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              spacing: Spacing.m,
              children: [
                ProductThumbnail(imagePath: product.imagePath),
                Expanded(
                  child: Text(
                    product.name,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
              ],
            ),
            const SizedBox(height: Spacing.xl),
            TextFormField(
              controller: _quantityController,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: InputDecoration(
                labelText: l10n.stockItemQuantityLabel,
              ),
              validator: (quantity) =>
                  _viewModel.isValidQuantity(quantity ?? '')
                  ? null
                  : l10n.stockItemQuantityInvalid,
            ),
            const SizedBox(height: Spacing.m),
            ChoiceSection(
              label: l10n.stockItemUnitLabel,
              children: [
                for (final unit in StockUnit.values)
                  ChoiceChip(
                    showCheckmark: false,
                    label: Text(unit.label(l10n)),
                    selected: unit == _unit,
                    onSelected: (_) => setState(() => _unit = unit),
                  ),
              ],
            ),
            const SizedBox(height: Spacing.xl),
            CalendarDateField(
              label: l10n.stockItemBestBeforeDateLabel,
              emptyText: l10n.stockItemWithoutBestBeforeDate,
              icon: Icons.event_rounded,
              date: _bestBeforeDate,
              initialPickerDate: today,
              onChanged: (date) => setState(() => _bestBeforeDate = date),
            ),
            const SizedBox(height: Spacing.l),
            CalendarDateField(
              label: l10n.stockItemOpenedDateLabel,
              emptyText: l10n.stockItemNotOpened,
              icon: Icons.lock_open_rounded,
              date: _openedDate,
              initialPickerDate: today,
              lastDate: today,
              onChanged: (date) => setState(() => _openedDate = date),
            ),
            const SizedBox(height: Spacing.xxl),
            FilledButton(
              onPressed: _isSaving ? null : _submit,
              child: Text(l10n.saveStockItem),
            ),
          ],
        ),
      ),
    );
  }
}
