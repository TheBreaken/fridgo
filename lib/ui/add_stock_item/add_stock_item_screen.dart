import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:fridgo/domain/calendar_date.dart';
import 'package:fridgo/domain/product_photo.dart';
import 'package:fridgo/domain/stock_item.dart';
import 'package:fridgo/domain/storage_location.dart';
import 'package:fridgo/l10n/app_localizations.dart';
import 'package:fridgo/ui/add_stock_item/add_stock_item_view_model.dart';
import 'package:fridgo/ui/add_stock_item/product_photo_field.dart';
import 'package:fridgo/ui/core/app_theme.dart';
import 'package:fridgo/ui/core/calendar_date_display.dart';
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
  static final _firstPickableDate = DateTime(2000);
  static final _lastPickableDate = DateTime(2100);

  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _quantityController = TextEditingController(text: '1');
  String? _storageLocationId;
  StockUnit _unit = StockUnit.piece;
  CalendarDate? _bestBeforeDate;
  CalendarDate? _openedDate;
  String? _pickedPhotoPath;
  bool _isSaving = false;

  AddStockItemViewModel get _viewModel =>
      ref.read(addStockItemViewModelProvider(widget.homeId).notifier);

  @override
  void dispose() {
    _nameController.dispose();
    _quantityController.dispose();
    super.dispose();
  }

  Future<void> _submit(String storageLocationId) async {
    if (_isSaving || !_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);
    await _viewModel.addStockItem(
      StockItemDraft(
        productName: _nameController.text,
        storageLocationId: storageLocationId,
        quantity: _viewModel.parseQuantity(_quantityController.text),
        unit: _unit,
        bestBeforeDate: _bestBeforeDate,
        openedDate: _openedDate,
      ),
      pickedPhotoPath: _pickedPhotoPath,
    );
    if (mounted) context.pop();
  }

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
      if (!mounted) return;
      final l10n = AppLocalizations.of(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(switch (error) {
            PhotoAccessDeniedException(source: PhotoSource.camera) =>
              l10n.productPhotoCameraAccessDenied,
            PhotoAccessDeniedException(source: PhotoSource.gallery) =>
              l10n.productPhotoGalleryAccessDenied,
            PhotoUnavailableException() => l10n.productPhotoUnavailable,
          }),
        ),
      );
    }
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
              ProductPhotoField(
                photoPath: _pickedPhotoPath,
                onTap: _changePhoto,
              ),
              const SizedBox(height: Spacing.xl),
              TextFormField(
                controller: _nameController,
                autofocus: true,
                textCapitalization: TextCapitalization.sentences,
                textInputAction: TextInputAction.next,
                decoration: InputDecoration(labelText: l10n.productNameLabel),
                validator: (name) => _viewModel.isValidName(name ?? '')
                    ? null
                    : l10n.productNameRequired,
              ),
              const SizedBox(height: Spacing.xl),
              _ChoiceSection(
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
              _ChoiceSection(
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
              _DateField(
                label: l10n.stockItemBestBeforeDateLabel,
                emptyText: l10n.stockItemWithoutBestBeforeDate,
                icon: Icons.event_rounded,
                date: _bestBeforeDate,
                initialPickerDate: today,
                firstDate: _firstPickableDate,
                lastDate: _lastPickableDate,
                onChanged: (date) => setState(() => _bestBeforeDate = date),
              ),
              const SizedBox(height: Spacing.l),
              _DateField(
                label: l10n.stockItemOpenedDateLabel,
                emptyText: l10n.stockItemNotOpened,
                icon: Icons.lock_open_rounded,
                date: _openedDate,
                initialPickerDate: today,
                firstDate: _firstPickableDate,
                lastDate: today,
                onChanged: (date) => setState(() => _openedDate = date),
              ),
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

class _ChoiceSection extends StatelessWidget {
  const new({required this.label, required this.children});

  final String label;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: Spacing.s,
      children: [
        Text(label, style: Theme.of(context).textTheme.labelLarge),
        Wrap(spacing: Spacing.s, runSpacing: Spacing.s, children: children),
      ],
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

class _DateField extends StatefulWidget {
  const new({
    required this.label,
    required this.emptyText,
    required this.icon,
    required this.date,
    required this.initialPickerDate,
    required this.firstDate,
    required this.lastDate,
    required this.onChanged,
  });

  final String label;
  final String emptyText;
  final IconData icon;
  final CalendarDate? date;
  final DateTime initialPickerDate;
  final DateTime firstDate;
  final DateTime lastDate;
  final ValueChanged<CalendarDate?> onChanged;

  @override
  State<_DateField> createState() => _DateFieldState();
}

class _DateFieldState extends State<_DateField> {
  final _controller = TextEditingController();

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _showDate();
  }

  @override
  void didUpdateWidget(_DateField oldWidget) {
    super.didUpdateWidget(oldWidget);
    _showDate();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _showDate() {
    _controller.text = widget.date?.format(AppLocalizations.of(context)) ?? '';
  }

  Future<void> _pick() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: widget.date?.toDateTime() ?? widget.initialPickerDate,
      firstDate: widget.firstDate,
      lastDate: widget.lastDate,
    );
    if (picked != null) widget.onChanged(CalendarDate.fromDateTime(picked));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return TextField(
      controller: _controller,
      readOnly: true,
      onTap: _pick,
      decoration: InputDecoration(
        labelText: widget.label,
        hintText: widget.emptyText,
        floatingLabelBehavior: FloatingLabelBehavior.always,
        prefixIcon: Icon(widget.icon),
        suffixIcon: widget.date == null
            ? null
            : IconButton(
                onPressed: () => widget.onChanged(null),
                tooltip: l10n.clearDate,
                icon: const Icon(Icons.close_rounded),
              ),
      ),
    );
  }
}
