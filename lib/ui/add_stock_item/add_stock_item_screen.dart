import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:fridgo/domain/calendar_date.dart';
import 'package:fridgo/domain/nutrient.dart';
import 'package:fridgo/domain/product.dart';
import 'package:fridgo/domain/product_photo.dart';
import 'package:fridgo/domain/stock_item.dart';
import 'package:fridgo/domain/storage_location.dart';
import 'package:fridgo/l10n/app_localizations.dart';
import 'package:fridgo/ui/add_stock_item/add_stock_item_view_model.dart';
import 'package:fridgo/ui/add_stock_item/product_name_field.dart';
import 'package:fridgo/ui/add_stock_item/selected_product_card.dart';
import 'package:fridgo/ui/core/app_theme.dart';
import 'package:fridgo/ui/core/calendar_date_field.dart';
import 'package:fridgo/ui/core/choice_section.dart';
import 'package:fridgo/ui/core/nutrition_facts_section.dart';
import 'package:fridgo/ui/core/product_photo_field.dart';
import 'package:fridgo/ui/core/stock_unit_display.dart';
import 'package:fridgo/ui/core/storage_location_kind_display.dart';
import 'package:go_router/go_router.dart';

class AddStockItemScreen extends ConsumerStatefulWidget {
  const new({required this.homeId, super.key});

  final String homeId;

  @override
  ConsumerState<AddStockItemScreen> createState() => _AddStockItemScreenState();
}

class _AddStockItemScreenState extends ConsumerState<AddStockItemScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _quantityController = TextEditingController(text: '1');
  final _nutritionFactsExpansion = ExpansibleController();
  final Map<Nutrient, TextEditingController> _nutrientControllers = {
    for (final nutrient in Nutrient.values) nutrient: TextEditingController(),
  };
  String? _storageLocationId;
  StockUnit _unit = StockUnit.piece;
  CalendarDate? _bestBeforeDate;
  CalendarDate? _openedDate;
  String? _pickedPhotoPath;
  Product? _selectedProduct;
  bool _isSaving = false;

  AddStockItemViewModel get _viewModel =>
      ref.read(addStockItemViewModelProvider(widget.homeId).notifier);

  @override
  void dispose() {
    _nameController.dispose();
    _quantityController.dispose();
    _nutritionFactsExpansion.dispose();
    for (final controller in _nutrientControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _submit(String storageLocationId) async {
    if (_isSaving) return;
    if (!_formKey.currentState!.validate()) {
      if (_selectedProduct == null && _hasInvalidNutrient) {
        _nutritionFactsExpansion.expand();
      }
      return;
    }
    setState(() => _isSaving = true);
    final draft = StockItemDraft(
      storageLocationId: storageLocationId,
      quantity: _viewModel.parseQuantity(_quantityController.text),
      unit: _unit,
      bestBeforeDate: _bestBeforeDate,
      openedDate: _openedDate,
    );
    final selectedProduct = _selectedProduct;
    if (selectedProduct == null) {
      await _viewModel.addStockItemWithNewProduct(
        draft,
        productName: _nameController.text,
        pickedPhotoPath: _pickedPhotoPath,
        nutritionFacts: _nutritionFacts,
      );
    } else {
      await _viewModel.addStockItemForProduct(selectedProduct.id, draft);
    }
    if (mounted) context.pop();
  }

  bool get _hasInvalidNutrient => _nutrientControllers.entries.any(
    (entry) => !_viewModel.isValidNutrient(entry.value.text, entry.key),
  );

  Map<Nutrient, double> get _nutritionFacts => {
    for (final MapEntry(key: nutrient, value: controller)
        in _nutrientControllers.entries)
      nutrient: ?_viewModel.parseNutrient(controller.text, nutrient),
  };

  void _selectProduct(Product product) => setState(() {
    _selectedProduct = product;
    _pickedPhotoPath = null;
  });

  Future<void> _editSelectedProduct(Product product) async {
    final deleted = await context.push<bool>('/products/${product.id}');
    if (deleted ?? false) {
      if (mounted) _clearSelectedProduct();
      return;
    }
    final edited = await _viewModel.getProduct(product.id);
    if (!mounted) return;
    if (edited == null) {
      _clearSelectedProduct();
    } else {
      setState(() => _selectedProduct = edited);
    }
  }

  void _clearSelectedProduct() => setState(() {
    _selectedProduct = null;
    _nameController.clear();
  });

  Future<void> _changePhoto() async {
    final action = await showPhotoActionSheet(
      context,
      hasPhoto: _pickedPhotoPath != null,
    );
    switch (action) {
      case null:
        return;
      case RemovePhoto():
        setState(() => _pickedPhotoPath = null);
      case PickPhoto(:final source):
        await _pickPhoto(source);
    }
  }

  Future<void> _pickPhoto(PhotoSource source) async {
    try {
      final path = await _viewModel.pickPhoto(source);
      if (path != null && mounted) setState(() => _pickedPhotoPath = path);
    } on PhotoPickException catch (error) {
      if (mounted) showPhotoPickError(context, error);
    }
  }

  Widget _buildProduct(AppLocalizations l10n) {
    final selectedProduct = _selectedProduct;
    if (selectedProduct != null) {
      return SelectedProductCard(
        key: ValueKey(selectedProduct.id),
        product: selectedProduct,
        onEdit: () => _editSelectedProduct(selectedProduct),
        onCleared: _clearSelectedProduct,
      );
    }
    return Column(
      key: const ValueKey('newProduct'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ProductPhotoField(
          photo: switch (_pickedPhotoPath) {
            final path? => File(path),
            null => null,
          },
          onTap: _changePhoto,
        ),
        const SizedBox(height: Spacing.xl),
        ProductNameField(
          controller: _nameController,
          findProducts: _viewModel.findProducts,
          onProductSelected: _selectProduct,
          validator: (name) => _viewModel.isValidName(name ?? '')
              ? null
              : l10n.productNameRequired,
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final storageLocations =
        ref.watch(addStockItemViewModelProvider(widget.homeId)).value ?? [];
    final selectedStorageLocationId =
        _storageLocationId ?? storageLocations.firstOrNull?.id;
    final today = _viewModel.today.toDateTime();
    return Scaffold(
      appBar: AppBar(title: Text(l10n.addStockItem)),
      body: Form(
        key: _formKey,
        autovalidateMode: AutovalidateMode.onUserInteractionIfError,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(Spacing.l),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AnimatedSize(
                duration: Durations.medium2,
                curve: Curves.easeInOut,
                alignment: Alignment.topCenter,
                child: AnimatedSwitcher(
                  duration: Durations.medium2,
                  child: _buildProduct(l10n),
                ),
              ),
              const SizedBox(height: Spacing.xl),
              ChoiceSection(
                label: l10n.stockItemStorageLocationLabel,
                children: [
                  for (final storageLocation in storageLocations)
                    _StorageLocationChip(
                      storageLocation: storageLocation,
                      selected: storageLocation.id == selectedStorageLocationId,
                      onSelected: () => setState(
                        () => _storageLocationId = storageLocation.id,
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
              if (_selectedProduct == null) ...[
                const SizedBox(height: Spacing.xl),
                NutritionFactsSection(
                  expansibleController: _nutritionFactsExpansion,
                  controllers: _nutrientControllers,
                  isValidInput: _viewModel.isValidNutrient,
                ),
              ],
              const SizedBox(height: Spacing.xxl),
              FilledButton(
                onPressed: _isSaving || selectedStorageLocationId == null
                    ? null
                    : () => _submit(selectedStorageLocationId),
                child: Text(l10n.createStockItem),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StorageLocationChip extends StatelessWidget {
  const new({
    required this.storageLocation,
    required this.selected,
    required this.onSelected,
  });

  final StorageLocation storageLocation;
  final bool selected;
  final VoidCallback onSelected;

  @override
  Widget build(BuildContext context) {
    return ChoiceChip(
      avatar: SvgPicture.asset(
        storageLocation.kind.emoji,
        excludeFromSemantics: true,
      ),
      showCheckmark: false,
      label: Text(storageLocation.name),
      selected: selected,
      onSelected: (_) => onSelected(),
    );
  }
}
