import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fridgo/domain/home.dart';
import 'package:fridgo/l10n/app_localizations.dart';
import 'package:fridgo/ui/core/app_theme.dart';
import 'package:fridgo/ui/homes/homes_view_model.dart';

/// Creates a home, or renames [home] if given.
Future<void> showCreateHomeSheet(BuildContext context, {Home? home}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (context) => CreateHomeSheet(home: home),
  );
}

class CreateHomeSheet extends ConsumerStatefulWidget {
  const new({this.home, super.key});

  final Home? home;

  @override
  ConsumerState<CreateHomeSheet> createState() => _CreateHomeSheetState();
}

class _CreateHomeSheetState extends ConsumerState<CreateHomeSheet> {
  final _formKey = GlobalKey<FormState>();
  late final _nameController = TextEditingController(text: widget.home?.name);
  bool _isSaving = false;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_isSaving || !_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);
    final viewModel = ref.read(homesViewModelProvider.notifier);
    final home = widget.home;
    await (home == null
        ? viewModel.createHome(_nameController.text)
        : viewModel.renameHome(home, _nameController.text));
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final viewModel = ref.read(homesViewModelProvider.notifier);
    final isRenaming = widget.home != null;
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
            Text(
              isRenaming ? l10n.renameHomeTitle : l10n.addHome,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            TextFormField(
              controller: _nameController,
              autofocus: true,
              textCapitalization: TextCapitalization.sentences,
              textInputAction: TextInputAction.done,
              decoration: InputDecoration(labelText: l10n.homeNameLabel),
              validator: (name) => viewModel.isValidName(name ?? '')
                  ? null
                  : l10n.homeNameRequired,
              onFieldSubmitted: (_) => _submit(),
            ),
            FilledButton(
              onPressed: _isSaving ? null : _submit,
              child: Text(isRenaming ? l10n.saveHome : l10n.createHome),
            ),
          ],
        ),
      ),
    );
  }
}
