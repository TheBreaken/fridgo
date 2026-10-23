import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fridgo/domain/barcode_scan.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

abstract interface class BarcodeScanner {
  /// Every barcode the camera sees, the same one again in later frames.
  Stream<String> get barcodes;

  /// Throws a [CameraException] if the camera cannot be used.
  Future<void> start();

  Future<void> stop();

  /// The camera picture; must be on screen when [start] is called.
  Widget buildPreview();
}

class MobileBarcodeScanner implements BarcodeScanner {
  new();

  // The formats on food packaging.
  final _controller = MobileScannerController(
    autoStart: false,
    formats: const [
      BarcodeFormat.ean13,
      BarcodeFormat.ean8,
      BarcodeFormat.upcA,
      BarcodeFormat.upcE,
    ],
  );
  AppLifecycleListener? _lifecycle;

  @override
  Stream<String> get barcodes => _controller.barcodes.expand(
    (capture) => [for (final barcode in capture.barcodes) ?barcode.rawValue],
  );

  @override
  Future<void> start() async {
    try {
      await _controller.start();
    } on MobileScannerException catch (error) {
      throw CameraUnavailableException(error.errorCode.name);
    }
    // start() reports a failing camera in the state instead of throwing.
    switch (_controller.value.error?.errorCode) {
      case null:
        break;
      case MobileScannerErrorCode.permissionDenied:
        throw const CameraAccessDeniedException();
      case final errorCode:
        throw CameraUnavailableException(errorCode.name);
    }
    // With its own controller the MobileScanner widget leaves pausing to us.
    _lifecycle ??= AppLifecycleListener(
      onInactive: () => unawaited(_controller.stop()),
      onResume: () => unawaited(_controller.start()),
    );
  }

  @override
  Future<void> stop() async {
    _lifecycle?.dispose();
    _lifecycle = null;
    await _controller.stop();
  }

  @override
  Widget buildPreview() => MobileScanner(
    controller: _controller,
    errorBuilder: (_, _) => const SizedBox.shrink(),
  );

  Future<void> dispose() async {
    _lifecycle?.dispose();
    await _controller.dispose();
  }
}

final Provider<BarcodeScanner> barcodeScannerProvider = Provider.autoDispose((
  ref,
) {
  final scanner = MobileBarcodeScanner();
  ref.onDispose(scanner.dispose);
  return scanner;
});
