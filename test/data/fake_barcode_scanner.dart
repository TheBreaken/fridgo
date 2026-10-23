import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:fridgo/data/barcode_scanner.dart';
import 'package:fridgo/domain/barcode_scan.dart';

class FakeBarcodeScanner implements BarcodeScanner {
  final _barcodes = StreamController<String>.broadcast();

  /// Thrown by [start] instead of starting.
  CameraException? startError;

  bool isRunning = false;

  /// Lets the camera see [barcode].
  void show(String barcode) => _barcodes.add(barcode);

  @override
  Stream<String> get barcodes => _barcodes.stream;

  @override
  Future<void> start() async {
    if (startError case final error?) throw error;
    isRunning = true;
  }

  @override
  Future<void> stop() async => isRunning = false;

  @override
  Widget buildPreview() => const SizedBox.expand();
}
