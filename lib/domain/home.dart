import 'package:freezed_annotation/freezed_annotation.dart';

part 'home.freezed.dart';

@freezed
abstract class Home with _$Home {
  const factory({required String id, required String name}) = _Home;
}
