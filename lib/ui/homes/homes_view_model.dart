import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fridgo/data/repositories/home_repository.dart';
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
}

final homesViewModelProvider =
    StreamNotifierProvider<HomesViewModel, List<Home>>(HomesViewModel.new);
