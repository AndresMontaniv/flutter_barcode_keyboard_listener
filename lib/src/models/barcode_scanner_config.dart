import 'package:flutter/services.dart';
import 'barcode_format.dart';

class BarcodeScannerConfig {
  final List<LogicalKeyboardKey> terminators;
  final Duration bufferTimeout;
  final Duration deduplicationWindow;
  final List<BarcodeFormat> allowedFormats;

  const BarcodeScannerConfig({
    this.terminators = const [
      LogicalKeyboardKey.enter,
      LogicalKeyboardKey.numpadEnter,
      LogicalKeyboardKey.tab,
    ],
    this.bufferTimeout = const Duration(milliseconds: 100),
    this.deduplicationWindow = const Duration(milliseconds: 500),
    this.allowedFormats = const [],
  });
}
