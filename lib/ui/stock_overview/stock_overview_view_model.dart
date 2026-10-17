import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:fridgo/data/clock.dart';
import 'package:fridgo/data/repositories/stock_item_repository.dart';
import 'package:fridgo/domain/calendar_date.dart';
import 'package:fridgo/domain/stock_item.dart';

final StreamProviderFamily<List<StockItemDetails>, String>
stockOverviewProvider = StreamProvider.autoDispose.family(
  (ref, homeId) =>
      ref.watch(stockItemRepositoryProvider).watchStockItems(homeId),
);

// The midnight timer alone is not enough: while the app sits in the
// background, the platform may suspend it and the timer fires late, so the
// day is also read again whenever the app comes back.
final Provider<CalendarDate> todayProvider = Provider.autoDispose((ref) {
  final now = ref.watch(clockProvider)();
  final nextMidnight = DateTime(now.year, now.month, now.day + 1);
  final midnightTimer = Timer(nextMidnight.difference(now), ref.invalidateSelf);
  final lifecycleListener = AppLifecycleListener(onResume: ref.invalidateSelf);
  ref.onDispose(() {
    midnightTimer.cancel();
    lifecycleListener.dispose();
  });
  return CalendarDate.fromDateTime(now);
});
