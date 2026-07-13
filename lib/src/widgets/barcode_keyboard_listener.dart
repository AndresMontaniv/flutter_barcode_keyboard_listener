import 'dart:async';
import 'package:flutter/widgets.dart';
import '../models/barcode_result.dart';
import '../models/barcode_scanner_config.dart';
import '../services/barcode_keyboard_service.dart';

/// A declarative widget wrapper that listens for physical HID barcode scanner
/// keystrokes in the background and triggers callbacks upon scan completion.
///
/// Unlike [KeyboardListener] and the deprecated `RawKeyboardListener`, this
/// widget does **not** use a [FocusNode]. HID barcode scanners inject
/// keystrokes at the OS level, so interception is global and independent of
/// the Flutter focus tree.
///
/// Automatically manages the underlying [BarcodeKeyboardService] lifecycle,
/// stream subscriptions, and hardware keyboard handlers. Supports:
///
/// * **Dynamic `enabled` toggle** — temporarily pause HID interception
///   (e.g., when a [TextField] or modal dialog is active) without destroying
///   the service instance.
/// * **Hot-swappable configuration** — changing [config] tears down the old
///   service and spins up a fresh instance with the new settings.
///
/// {@tool snippet}
/// ```dart
/// BarcodeKeyboardListener(
///   onBarcodeScanned: (capture) => print(capture.rawValue),
///   onBarcodeRejected: (rejection) => print(rejection.reason),
///   child: const Text('Listening for scans…'),
/// )
/// ```
/// {@end-tool}
class BarcodeKeyboardListener extends StatefulWidget {
  /// The widget subtree rendered below this listener.
  final Widget child;

  /// Callback invoked when a barcode is successfully scanned and validated
  /// against the configured symbologies.
  final ValueChanged<BarcodeCapture> onBarcodeScanned;

  /// Optional callback invoked when a scan is rejected due to format rules,
  /// buffer overflows, or temporal deduplication.
  ///
  /// When `null`, rejection events are silently discarded without subscribing
  /// to the underlying stream.
  final ValueChanged<BarcodeRejection>? onBarcodeRejected;

  /// Configuration governing hardware buffer timeouts, terminators, and
  /// allowed symbologies. Defaults to standard retail settings.
  final BarcodeScannerConfig config;

  /// Whether background HID keystroke interception is actively enabled.
  ///
  /// When set to `false`, the keyboard handler is temporarily removed,
  /// allowing normal keyboard input to pass through unintercepted.
  /// Defaults to `true`.
  final bool enabled;

  /// Creates a declarative barcode keyboard listener widget.
  const BarcodeKeyboardListener({
    super.key,
    required this.child,
    required this.onBarcodeScanned,
    this.onBarcodeRejected,
    this.config = const BarcodeScannerConfig(),
    this.enabled = true,
  });

  @override
  State<BarcodeKeyboardListener> createState() =>
      _BarcodeKeyboardListenerState();
}

class _BarcodeKeyboardListenerState extends State<BarcodeKeyboardListener> {
  late BarcodeKeyboardService _service;
  StreamSubscription<BarcodeCapture>? _captureSub;
  StreamSubscription<BarcodeRejection>? _rejectionSub;

  @override
  void initState() {
    super.initState();
    _initService();
  }

  void _initService() {
    _service = BarcodeKeyboardService(widget.config);
    _captureSub = _service.barcodeStream.listen((capture) {
      widget.onBarcodeScanned(capture);
    });

    if (widget.onBarcodeRejected != null) {
      _rejectionSub = _service.rejectionStream.listen((rejection) {
        widget.onBarcodeRejected?.call(rejection);
      });
    }

    if (widget.enabled) {
      _service.start();
    }
  }

  void _teardownService() {
    _captureSub?.cancel();
    _rejectionSub?.cancel();
    _service.dispose();
  }

  @override
  void didUpdateWidget(BarcodeKeyboardListener oldWidget) {
    super.didUpdateWidget(oldWidget);

    // 1. If configuration changed, hot-swap the entire service instance.
    if (widget.config != oldWidget.config) {
      _teardownService();
      _initService();
      return;
    }

    // 2. If rejection subscription requirement changed (null ↔ non-null),
    //    update the stream subscription. Ignore callback identity changes
    //    from inline closures — the listener reads `widget.onBarcodeRejected`
    //    at call-time so it always invokes the latest reference.
    final hadRejection = oldWidget.onBarcodeRejected != null;
    final hasRejection = widget.onBarcodeRejected != null;
    if (hadRejection != hasRejection) {
      _rejectionSub?.cancel();
      if (hasRejection) {
        _rejectionSub = _service.rejectionStream.listen((rejection) {
          widget.onBarcodeRejected?.call(rejection);
        });
      } else {
        _rejectionSub = null;
      }
    }

    // 3. If active listening state toggled, pause or resume hardware handler.
    if (widget.enabled != oldWidget.enabled) {
      if (widget.enabled) {
        _service.start();
      } else {
        _service.stop();
      }
    }
  }

  @override
  void dispose() {
    _teardownService();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
