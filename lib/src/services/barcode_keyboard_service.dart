import 'dart:async';
import 'package:flutter/services.dart';
import '../models/barcode_scanner_config.dart';

/// A headless service that intercepts raw system keystrokes via
/// [HardwareKeyboard], assembles them into a buffer, validates against
/// configured [BarcodeFormat] symbologies, and emits deduplicated barcode
/// strings through a broadcast [Stream].
class BarcodeKeyboardService {
  final BarcodeScannerConfig config;

  final StreamController<String> _controller =
      StreamController<String>.broadcast();
  final StringBuffer _buffer = StringBuffer();
  DateTime? _lastEventTime;
  DateTime? _lastScannedTime;
  String? _lastScannedCode;

  /// Creates a [BarcodeKeyboardService] with the given [config].
  BarcodeKeyboardService(this.config);

  /// A broadcast stream of validated, deduplicated barcode strings.
  Stream<String> get barcodeStream => _controller.stream;

  /// Registers the keyboard handler with [HardwareKeyboard].
  void start() {
    HardwareKeyboard.instance.addHandler(_handleKeyEvent);
  }

  /// Removes the keyboard handler from [HardwareKeyboard].
  void stop() {
    HardwareKeyboard.instance.removeHandler(_handleKeyEvent);
  }

  /// Removes the keyboard handler and closes the stream controller.
  void dispose() {
    stop();
    _controller.close();
  }

  bool _handleKeyEvent(KeyEvent event) {
    // Only process key-down events.
    if (event is! KeyDownEvent) return false;

    final now = DateTime.now();

    // Timeout guard: if too much time elapsed since the last keystroke,
    // the buffer contains human typing – purge it.
    if (_lastEventTime != null &&
        now.difference(_lastEventTime!) > config.bufferTimeout) {
      _buffer.clear();
    }
    _lastEventTime = now;

    // Check if this keystroke is a configured terminator (scan complete).
    if (config.terminators.contains(event.logicalKey)) {
      final scannedCode = _buffer.toString();
      _buffer.clear();

      if (scannedCode.isEmpty) return false;

      // Format validation: if allowedFormats is non-empty, the code must
      // match at least one format's regex.
      if (config.allowedFormats.isNotEmpty) {
        final matchesAny = config.allowedFormats.any(
          (format) => format.validationRegex.hasMatch(scannedCode),
        );
        if (!matchesAny) return false;
      }

      // Deduplication shield: reject duplicate scans within the window.
      if (_lastScannedCode == scannedCode &&
          _lastScannedTime != null &&
          now.difference(_lastScannedTime!) < config.deduplicationWindow) {
        return false;
      }

      _lastScannedCode = scannedCode;
      _lastScannedTime = now;
      _controller.sink.add(scannedCode);
    } else {
      // Ongoing scan – accumulate printable characters.
      final character = event.character;
      if (character != null && character.isNotEmpty) {
        _buffer.write(character);
      }
    }

    return false;
  }
}
