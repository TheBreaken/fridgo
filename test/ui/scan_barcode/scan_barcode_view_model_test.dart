import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fridgo/data/barcode_scanner.dart';
import 'package:fridgo/domain/barcode_scan.dart';
import 'package:fridgo/ui/scan_barcode/scan_barcode_view_model.dart';

import '../../data/fake_barcode_scanner.dart';

ProviderContainer _listeningContainer(FakeBarcodeScanner scanner) {
  final container = ProviderContainer(
    overrides: [barcodeScannerProvider.overrideWithValue(scanner)],
  );
  addTearDown(container.dispose);
  container.listen(scanBarcodeViewModelProvider, (_, _) {});
  return container;
}

void main() {
  test('opening the scanner starts the camera and scans', () async {
    final scanner = FakeBarcodeScanner();

    final container = _listeningContainer(scanner);
    await pumpEventQueue();

    expect(scanner.isRunning, isTrue);
    expect(
      container.read(scanBarcodeViewModelProvider),
      const ScanBarcodeState.scanning(),
    );
  });

  test('the first barcode is the result and stops the camera', () async {
    final scanner = FakeBarcodeScanner();
    final container = _listeningContainer(scanner);
    await pumpEventQueue();

    scanner.show('4012345678901');
    await pumpEventQueue();

    expect(
      container.read(scanBarcodeViewModelProvider),
      const ScanBarcodeState.barcodeFound('4012345678901'),
    );
    expect(scanner.isRunning, isFalse);
  });

  test('a barcode seen after the first one does not replace it', () async {
    final scanner = FakeBarcodeScanner();
    final container = _listeningContainer(scanner);
    await pumpEventQueue();

    scanner
      ..show('4012345678901')
      ..show('4098765432109');
    await pumpEventQueue();

    expect(
      container.read(scanBarcodeViewModelProvider),
      const ScanBarcodeState.barcodeFound('4012345678901'),
    );
  });

  final cameraErrorCases = {
    'a denied camera ends in camera denied': (
      error: const CameraAccessDeniedException(),
      state: const ScanBarcodeState.cameraDenied(),
    ),
    'a missing camera ends in camera unavailable': (
      error: const CameraUnavailableException('unsupported'),
      state: const ScanBarcodeState.cameraUnavailable(),
    ),
  };
  for (final MapEntry(key: description, value: (:error, :state))
      in cameraErrorCases.entries) {
    test(description, () async {
      final scanner = FakeBarcodeScanner()..startError = error;

      final container = _listeningContainer(scanner);
      await pumpEventQueue();

      expect(container.read(scanBarcodeViewModelProvider), state);
    });
  }

  test('a barcode after a camera error changes nothing', () async {
    final scanner = FakeBarcodeScanner()
      ..startError = const CameraAccessDeniedException();
    final container = _listeningContainer(scanner);
    await pumpEventQueue();

    scanner.show('4012345678901');
    await pumpEventQueue();

    expect(
      container.read(scanBarcodeViewModelProvider),
      const ScanBarcodeState.cameraDenied(),
    );
  });
}
