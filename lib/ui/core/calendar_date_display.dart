import 'package:fridgo/domain/calendar_date.dart';
import 'package:fridgo/l10n/app_localizations.dart';
import 'package:intl/intl.dart';

extension CalendarDateDisplay on CalendarDate {
  String format(AppLocalizations l10n) =>
      DateFormat.yMd(l10n.localeName).format(toDateTime());
}
