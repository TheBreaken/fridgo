import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fridgo/data/repositories/product_repository.dart';
import 'package:fridgo/domain/nutrient.dart';
import 'package:fridgo/domain/product.dart';
import 'package:fridgo/domain/product_photo.dart';
import 'package:fridgo/l10n/app_localizations.dart';
import 'package:fridgo/ui/core/app_theme.dart';
import 'package:fridgo/ui/core/nutrition_facts_section.dart';
import 'package:fridgo/ui/core/product_photo_field.dart';
import 'package:fridgo/ui/core/product_thumbnail.dart';
import 'package:fridgo/ui/core/stock_unit_display.dart';
import 'package:fridgo/ui/edit_product/edit_product_view_model.dart';
import 'package:go_router/go_router.dart';

class EditProductScreen extends ConsumerWidget {
  const new({required this.productId, super.key});

  final String productId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final editable = ref.watch(editableProductProvider(productId));
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.editProduct),
        actions: [
          if (editable.value case (:final product, :final stock))
            IconButton(
              onPressed: () => _delete(context, ref, product, stock),
              tooltip: l10n.deleteProduct,
              icon: const Icon(Icons.delete_rounded),
            ),
        ],
      ),
      body: switch (editable) {
        AsyncError(:final error, :final stackTrace) =>
          Error.throwWithStackTrace(error, stackTrace),
        AsyncData(:final value?) => _EditProductForm(product: value.product),
        _ => const SizedBox.shrink(),
      },
    );
  }

  Future<void> _delete(
    BuildContext context,
    WidgetRef ref,
    Product product,
    ProductStock stock,
  ) async {
    final l10n = AppLocalizations.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.deleteProductTitle(product.name)),
        content: Text(switch (stock) {
          (stockItemCount: 0, homeNames: _) => l10n.deleteProductMessage,
          (:final stockItemCount, :final homeNames) =>
            l10n.deleteProductWithStockMessage(
              stockItemCount,
              _listHomeNames(homeNames, l10n),
            ),
        }),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(l10n.cancel),
          ),
          TextButton(
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(context).colorScheme.error,
            ),
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(l10n.deleteProduct),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    final viewModel = ref.read(editProductViewModelProvider);
    // Back first with the result, so the details of a deleted stock item can
    // close before they would show nothing.
    context.pop(true);
    await viewModel.delete(product);
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(content: Text(l10n.productDeleted(product.name))),
      );
  }
}

String _listHomeNames(List<String> homeNames, AppLocalizations l10n) {
  if (homeNames.length == 1) return homeNames.single;
  return l10n.homeNameList(
    homeNames.sublist(0, homeNames.length - 1).join(', '),
    homeNames.last,
  );
}

class _EditProductForm extends ConsumerStatefulWidget {
  const new({required this.product});

  final Product product;

  @override
  ConsumerState<_EditProductForm> createState() => _EditProductFormState();
}

class _EditProductFormState extends ConsumerState<_EditProductForm> {
  final _formKey = GlobalKey<FormState>();
  late final _nameController = TextEditingController(text: widget.product.name);
  final _nutritionFactsExpansion = ExpansibleController();
  late final Map<Nutrient, TextEditingController> _nutrientControllers = {
    for (final nutrient in Nutrient.values)
      nutrient: TextEditingController(
        text: switch (widget.product.nutritionFacts[nutrient]) {
          final value? => formatQuantityNumber(
            value,
            AppLocalizations.of(context),
          ),
          null => '',
        },
      ),
  };

  // The stored photo, null once removed; a picked photo replaces it.
  late String? _imagePath = widget.product.imagePath;
  String? _pickedPhotoPath;
  bool _isSaving = false;

  EditProductViewModel get _viewModel => ref.read(editProductViewModelProvider);

  @override
  void dispose() {
    _nameController.dispose();
    _nutritionFactsExpansion.dispose();
    for (final controller in _nutrientControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _submit() async {
    if (_isSaving) return;
    if (!_formKey.currentState!.validate()) {
      if (_hasInvalidNutrient) _nutritionFactsExpansion.expand();
      return;
    }
    setState(() => _isSaving = true);
    await _viewModel.save(
      widget.product.copyWith(
        name: _nameController.text,
        imagePath: _imagePath,
        nutritionFacts: _nutritionFacts,
      ),
      pickedPhotoPath: _pickedPhotoPath,
    );
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

  Future<void> _changePhoto() async {
    final action = await showPhotoActionSheet(
      context,
      hasPhoto: _pickedPhotoPath != null || _imagePath != null,
    );
    switch (action) {
      case null:
        return;
      case RemovePhoto():
        setState(() {
          _pickedPhotoPath = null;
          _imagePath = null;
        });
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

  File? _photo() {
    if (_pickedPhotoPath case final pickedPhotoPath?) {
      return File(pickedPhotoPath);
    }
    if (_imagePath case final imagePath?) {
      return ref.watch(productImageFileProvider(imagePath)).value;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return Form(
      key: _formKey,
      autovalidateMode: AutovalidateMode.onUserInteractionIfError,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(Spacing.l),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ProductPhotoField(photo: _photo(), onTap: _changePhoto),
            const SizedBox(height: Spacing.xl),
            TextFormField(
              controller: _nameController,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(labelText: l10n.productNameLabel),
              validator: (name) => _viewModel.isValidName(name ?? '')
                  ? null
                  : l10n.productNameRequired,
            ),
            const SizedBox(height: Spacing.m),
            Row(
              spacing: Spacing.s,
              children: [
                Icon(
                  Icons.info_outline_rounded,
                  size: Sizes.inlineIcon,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                Expanded(
                  child: Text(
                    l10n.productChangesApplyToAllStockItems,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: Spacing.xl),
            NutritionFactsSection(
              expansibleController: _nutritionFactsExpansion,
              controllers: _nutrientControllers,
              isValidInput: _viewModel.isValidNutrient,
              initiallyExpanded: widget.product.nutritionFacts.isNotEmpty,
            ),
            const SizedBox(height: Spacing.xxl),
            FilledButton(
              onPressed: _isSaving ? null : _submit,
              child: Text(l10n.saveProduct),
            ),
          ],
        ),
      ),
    );
  }
}
