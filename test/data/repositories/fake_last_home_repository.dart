import 'package:fridgo/data/repositories/last_home_repository.dart';

class FakeLastHomeRepository implements LastHomeRepository {
  new({this.lastHomeId});

  String? lastHomeId;

  @override
  Future<String?> getLastHomeId() async => lastHomeId;

  @override
  Future<void> rememberLastHome(String homeId) async => lastHomeId = homeId;
}
