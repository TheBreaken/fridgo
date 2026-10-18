import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LastHomeRepository {
  new(this._preferences);

  static const _lastHomeIdKey = 'lastHomeId';

  final SharedPreferencesAsync _preferences;

  Future<String?> getLastHomeId() => _preferences.getString(_lastHomeIdKey);

  Future<void> rememberLastHome(String homeId) =>
      _preferences.setString(_lastHomeIdKey, homeId);
}

final lastHomeRepositoryProvider = Provider<LastHomeRepository>(
  (ref) => LastHomeRepository(SharedPreferencesAsync()),
);
