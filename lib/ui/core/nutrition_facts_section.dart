import 'package:flutter/material.dart';
import 'package:fridgo/domain/nutrient.dart';
import 'package:fridgo/l10n/app_localizations.dart';
import 'package:fridgo/ui/core/app_theme.dart';
import 'package:fridgo/ui/core/nutrient_display.dart';

class NutritionFactsSection extends StatelessWidget {
  const new({
    required this.expansibleController,
    required this.controllers,
    required this.isValidInput,
    this.initiallyExpanded = false,
    super.key,
  });

  final ExpansibleController expansibleController;
  final Map<Nutrient, TextEditingController> controllers;
  final bool Function(String input, Nutrient nutrient) isValidInput;
  final bool initiallyExpanded;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Card(
      clipBehavior: Clip.antiAlias,
      child: ExpansionTile(
        controller: expansibleController,
        initiallyExpanded: initiallyExpanded,
        // Collapsed fields must stay built, or Form.validate skips them.
        maintainState: true,
        shape: const Border(),
        collapsedShape: const Border(),
        leading: const Icon(Icons.local_dining_rounded),
        title: Text(l10n.nutritionFactsOptionalTitle),
        subtitle: Text(l10n.nutritionFactsReference),
        childrenPadding: const EdgeInsets.fromLTRB(
          Spacing.l,
          0,
          Spacing.l,
          Spacing.l,
        ),
        children: [
          for (final nutrient in Nutrient.values)
            Padding(
              padding: EdgeInsetsDirectional.only(
                top: Spacing.m,
                start: nutrient.isPartOfPrevious ? Spacing.xl : 0,
              ),
              child: TextFormField(
                controller: controllers[nutrient],
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: InputDecoration(
                  labelText: nutrient.label(l10n),
                  suffixText: nutrient.unit(l10n),
                  errorMaxLines: 2,
                ),
                validator: (input) => isValidInput(input ?? '', nutrient)
                    ? null
                    : l10n.nutrientValueInvalid(
                        nutrient.formatAmount(nutrient.maximum, l10n),
                      ),
              ),
            ),
        ],
      ),
    );
  }
}
