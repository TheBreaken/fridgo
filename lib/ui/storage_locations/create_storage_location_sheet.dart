import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:fridgo/domain/storage_location.dart';
import 'package:fridgo/l10n/app_localizations.dart';
import 'package:fridgo/ui/core/app_theme.dart';
import 'package:fridgo/ui/core/storage_location_kind_display.dart';
import 'package:fridgo/ui/storage_locations/storage_locations_view_model.dart';

Future<void> showCreateStorageLocationSheet(
  BuildContext context,
  String homeId,
) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (context) => CreateStorageLocationSheet(homeId: homeId),
  );
}

class CreateStorageLocationSheet extends ConsumerStatefulWidget {
  const new({required this.homeId, super.key});

  final String homeId;

  @override
  ConsumerState<CreateStorageLocationSheet> createState() =>
      _CreateStorageLocationSheetState();
}

class _CreateStorageLocationSheetState
    extends ConsumerState<CreateStorageLocationSheet> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  StorageLocationKind _kind = StorageLocationKind.refrigerator;
  bool _isSaving = false;

  StorageLocationsViewModel get _viewModel =>
      ref.read(storageLocationsViewModelProvider(widget.homeId).notifier);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_nameController.text.isEmpty) {
      _nameController.text = _kind.label(AppLocalizations.of(context));
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  void _selectKind(StorageLocationKind kind) {
    final l10n = AppLocalizations.of(context);
    setState(() {
      if (_nameController.text == _kind.label(l10n)) {
        _nameController.text = kind.label(l10n);
      }
      _kind = kind;
    });
  }

  Future<void> _submit() async {
    if (_isSaving || !_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);
    await _viewModel.createStorageLocation(_nameController.text, _kind);
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
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
            Text(l10n.addStorageLocation, style: theme.textTheme.titleLarge),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              spacing: Spacing.s,
              children: [
                Text(
                  l10n.storageLocationKindLabel,
                  style: theme.textTheme.labelLarge,
                ),
                Wrap(
                  spacing: Spacing.s,
                  runSpacing: Spacing.s,
                  children: [
                    for (final kind in StorageLocationKind.values)
                      ChoiceChip(
                        avatar: SvgPicture.asset(
                          kind.emoji,
                          excludeFromSemantics: true,
                        ),
                        showCheckmark: false,
                        label: Text(kind.label(l10n)),
                        selected: kind == _kind,
                        onSelected: (_) => _selectKind(kind),
                      ),
                  ],
                ),
              ],
            ),
            TextFormField(
              controller: _nameController,
              textCapitalization: TextCapitalization.sentences,
              textInputAction: TextInputAction.done,
              decoration: InputDecoration(
                labelText: l10n.storageLocationNameLabel,
              ),
              validator: (name) => _viewModel.isValidName(name ?? '')
                  ? null
                  : l10n.storageLocationNameRequired,
              onFieldSubmitted: (_) => _submit(),
            ),
            FilledButton(
              onPressed: _isSaving ? null : _submit,
              child: Text(l10n.createStorageLocation),
            ),
          ],
        ),
      ),
    );
  }
}
