import 'package:flutter/material.dart';
import 'package:fridgo/domain/calendar_date.dart';
import 'package:fridgo/l10n/app_localizations.dart';
import 'package:fridgo/ui/core/calendar_date_display.dart';

class CalendarDateField extends StatefulWidget {
  const new({
    required this.label,
    required this.emptyText,
    required this.icon,
    required this.date,
    required this.initialPickerDate,
    required this.onChanged,
    this.lastDate,
    super.key,
  });

  final String label;
  final String emptyText;
  final IconData icon;
  final CalendarDate? date;
  final DateTime initialPickerDate;
  final DateTime? lastDate;
  final ValueChanged<CalendarDate?> onChanged;

  @override
  State<CalendarDateField> createState() => _CalendarDateFieldState();
}

class _CalendarDateFieldState extends State<CalendarDateField> {
  static final _firstPickableDate = DateTime(2000);
  static final _lastPickableDate = DateTime(2100);

  final _controller = TextEditingController();

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _showDate();
  }

  @override
  void didUpdateWidget(CalendarDateField oldWidget) {
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
      firstDate: _firstPickableDate,
      lastDate: widget.lastDate ?? _lastPickableDate,
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
