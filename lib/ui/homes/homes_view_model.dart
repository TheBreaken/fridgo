import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fridgo/data/repositories/home_repository.dart';
import 'package:fridgo/data/repositories/last_home_repository.dart';
import 'package:fridgo/domain/home.dart';

class HomesViewModel extends StreamNotifier<List<Home>> {
  @override
  Stream<List<Home>> build() => ref.watch(homeRepositoryProvider).watchHomes();

  bool isValidName(String name) => name.trim().isNotEmpty;

  Future<void> createHome(String name) async {
    if (!isValidName(name)) {
      throw ArgumentError.value(name, 'name', 'must not be blank');
    }
    await ref.read(homeRepositoryProvider).createHome(name.trim());
  }

  /// The last selected home if it still exists, otherwise the first one.
  Future<String?> findStartHomeId() async {
    final lastHomeId = await ref
        .read(lastHomeRepositoryProvider)
        .getLastHomeId();
    final homes = await ref.read(homeRepositoryProvider).getHomes();
    if (homes.isEmpty) return null;
    return homes
        .firstWhere((home) => home.id == lastHomeId, orElse: () => homes.first)
        .id;
  }

  Future<void> selectHome(String homeId) =>
      ref.read(lastHomeRepositoryProvider).rememberLastHome(homeId);
}

final homesViewModelProvider =
    StreamNotifierProvider<HomesViewModel, List<Home>>(HomesViewModel.new);
