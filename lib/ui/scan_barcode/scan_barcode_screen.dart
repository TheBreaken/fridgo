import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fridgo/l10n/app_localizations.dart';
import 'package:fridgo/ui/core/app_theme.dart';
import 'package:fridgo/ui/scan_barcode/scan_barcode_view_model.dart';
import 'package:go_router/go_router.dart';

class ScanBarcodeScreen extends ConsumerWidget {
  const new({required this.homeId, super.key});

  final String homeId;

  String get _addStockItemPath => '/homes/$homeId/stock-items/new';

  void _addManually(BuildContext context, {String? reason}) {
    final messenger = ScaffoldMessenger.of(context);
    context.go(_addStockItemPath);
    if (reason != null) {
      messenger.showSnackBar(SnackBar(content: Text(reason)));
    }
  }

  void _addScanned(BuildContext context, String barcode) => context.go(
    Uri(
      path: _addStockItemPath,
      queryParameters: {'barcode': barcode},
    ).toString(),
  );

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    ref.listen(scanBarcodeViewModelProvider, (_, state) {
      switch (state) {
        case Scanning():
          break;
        case BarcodeFound():
          unawaited(HapticFeedback.mediumImpact());
        case CameraDenied():
          _addManually(context, reason: l10n.scanCameraAccessDenied);
        case CameraUnavailable():
          _addManually(context, reason: l10n.scanCameraUnavailable);
      }
    });
    final state = ref.watch(scanBarcodeViewModelProvider);
    final viewModel = ref.read(scanBarcodeViewModelProvider.notifier);
    // The camera picture is dark whatever the system setting.
    return Theme(
      data: AppTheme.dark,
      child: Builder(
        builder: (context) => Scaffold(
          appBar: AppBar(title: Text(l10n.scanBarcodeTitle)),
          body: Stack(
            fit: StackFit.expand,
            children: [
              viewModel.buildPreview(),
              _ScanFrame(
                isFound: state is BarcodeFound,
                onFoundShown: () {
                  if (state case BarcodeFound(:final barcode)) {
                    _addScanned(context, barcode);
                  }
                },
              ),
            ],
          ),
          // Here, unlike in the body, a snack bar from the overview shows
          // above the button instead of covering it.
          bottomNavigationBar: SafeArea(
            minimum: const EdgeInsets.all(Spacing.l),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              spacing: Spacing.l,
              children: [
                Text(
                  l10n.scanBarcodeHint,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                FilledButton.tonalIcon(
                  onPressed: () => _addManually(context),
                  icon: const Icon(Icons.edit_rounded),
                  label: Text(l10n.addWithoutBarcode),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Darkens the picture around a window for the barcode; the window's border
/// turns green on a hit and calls [onFoundShown] once it has.
class _ScanFrame extends StatelessWidget {
  const new({required this.isFound, required this.onFoundShown});

  final bool isFound;
  final VoidCallback onFoundShown;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = constraints.biggest;
        final width = size.width - 2 * Spacing.xxl;
        // Barcodes on packaging are about twice as wide as high.
        final window = Rect.fromCenter(
          center: size.center(Offset.zero),
          width: width,
          height: width / 2,
        );
        return Stack(
          children: [
            Positioned.fill(
              child: CustomPaint(
                painter: _ScrimPainter(
                  window: window,
                  color: colorScheme.scrim.withValues(alpha: 0.6),
                ),
              ),
            ),
            Positioned.fromRect(
              rect: window,
              child: AnimatedContainer(
                duration: Durations.short4,
                onEnd: isFound ? onFoundShown : null,
                decoration: BoxDecoration(
                  border: Border.all(
                    color: isFound
                        ? colorScheme.primary
                        : colorScheme.onSurface,
                    width: Sizes.scanFrameBorder,
                  ),
                  borderRadius: BorderRadius.circular(Corners.large),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _ScrimPainter extends CustomPainter {
  const new({required this.window, required this.color});

  final Rect window;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final scrim = Path()
      ..fillType = PathFillType.evenOdd
      ..addRect(Offset.zero & size)
      ..addRRect(
        RRect.fromRectAndRadius(window, const Radius.circular(Corners.large)),
      );
    canvas.drawPath(scrim, Paint()..color = color);
  }

  @override
  bool shouldRepaint(_ScrimPainter oldDelegate) =>
      oldDelegate.window != window || oldDelegate.color != color;
}
