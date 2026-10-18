import 'package:flutter/material.dart';
import 'package:fridgo/domain/product.dart';
import 'package:fridgo/l10n/app_localizations.dart';
import 'package:fridgo/ui/core/app_theme.dart';
import 'package:fridgo/ui/core/product_thumbnail.dart';

/// The name of a new product, suggesting existing products while typing.
class ProductNameField extends StatefulWidget {
  const new({
    required this.controller,
    required this.findProducts,
    required this.onProductSelected,
    required this.validator,
    super.key,
  });

  final TextEditingController controller;
  final Future<List<Product>> Function(String query) findProducts;
  final ValueChanged<Product> onProductSelected;
  final FormFieldValidator<String> validator;

  @override
  State<ProductNameField> createState() => _ProductNameFieldState();
}

class _ProductNameFieldState extends State<ProductNameField> {
  static const _visibleSuggestions = 3;
  static const double _suggestionHeight = Sizes.thumbnail + 2 * Spacing.s;

  final _focusNode = FocusNode();

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RawAutocomplete<Product>(
      textEditingController: widget.controller,
      focusNode: _focusNode,
      optionsBuilder: (value) => widget.findProducts(value.text),
      displayStringForOption: (product) => product.name,
      onSelected: widget.onProductSelected,
      // The submit callback is left out on purpose: the keyboard's next key
      // must not pick the first suggestion, a typed name is a new product.
      fieldViewBuilder: (context, controller, focusNode, _) => TextFormField(
        controller: controller,
        focusNode: focusNode,
        autofocus: true,
        textCapitalization: TextCapitalization.sentences,
        textInputAction: TextInputAction.next,
        decoration: InputDecoration(
          labelText: AppLocalizations.of(context).productNameLabel,
        ),
        validator: widget.validator,
      ),
      optionsViewBuilder: (context, onSelected, products) => _Suggestions(
        products: products.toList(),
        onSelected: onSelected,
        maxHeight: _visibleSuggestions * _suggestionHeight,
      ),
    );
  }
}

class _Suggestions extends StatelessWidget {
  const new({
    required this.products,
    required this.onSelected,
    required this.maxHeight,
  });

  final List<Product> products;
  final ValueChanged<Product> onSelected;
  final double maxHeight;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: Spacing.xs),
      child: Material(
        color: theme.colorScheme.surface,
        // The elevation of Flutter's own autocomplete options.
        elevation: 4,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(Corners.small),
          side: BorderSide(color: theme.colorScheme.outlineVariant),
        ),
        clipBehavior: Clip.antiAlias,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: maxHeight),
          child: ListView.builder(
            padding: EdgeInsets.zero,
            shrinkWrap: true,
            itemCount: products.length,
            itemBuilder: (context, index) {
              final product = products[index];
              return InkWell(
                onTap: () => onSelected(product),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: Spacing.m,
                    vertical: Spacing.s,
                  ),
                  child: Row(
                    spacing: Spacing.m,
                    children: [
                      ProductThumbnail(imagePath: product.imagePath),
                      Expanded(
                        child: Text(
                          product.name,
                          style: theme.textTheme.titleMedium,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
