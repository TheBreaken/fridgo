import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:fridgo/data/barcode_scanner.dart';
import 'package:fridgo/domain/barcode_scan.dart';

part 'scan_barcode_view_model.freezed.dart';

@freezed
sealed class ScanBarcodeState with _$ScanBarcodeState {
  const factory scanning() = Scanning;

  const factory barcodeFound(String barcode) = BarcodeFound;

  const factory cameraDenied() = CameraDenied;

  const factory cameraUnavailable() = CameraUnavailable;
}

/// Starts the camera and settles on the first barcode it sees.
class ScanBarcodeViewModel extends Notifier<ScanBarcodeState> {
  @override
  ScanBarcodeState build() {
    final scanner = ref.watch(barcodeScannerProvider);
    final subscription = scanner.barcodes.listen(_onBarcode);
    ref.onDispose(subscription.cancel);
    unawaited(_start(scanner));
    return const ScanBarcodeState.scanning();
  }

  Widget buildPreview() => ref.read(barcodeScannerProvider).buildPreview();

  Future<void> _start(BarcodeScanner scanner) async {
    try {
      await scanner.start();
    } on CameraException catch (error) {
      if (!ref.mounted) return;
      state = switch (error) {
        CameraAccessDeniedException() => const ScanBarcodeState.cameraDenied(),
        CameraUnavailableException() =>
          const ScanBarcodeState.cameraUnavailable(),
      };
    }
  }

  void _onBarcode(String barcode) {
    if (state is! Scanning) return;
    state = ScanBarcodeState.barcodeFound(barcode);
    unawaited(ref.read(barcodeScannerProvider).stop());
  }
}

final NotifierProvider<ScanBarcodeViewModel, ScanBarcodeState>
scanBarcodeViewModelProvider = NotifierProvider.autoDispose(
  ScanBarcodeViewModel.new,
);
