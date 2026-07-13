import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'barcode_format.dart';

/// Configuration for [BarcodeKeyboardService], controlling timing, symbology
/// filtering, deduplication, and safety limits.
class BarcodeScannerConfig {
  /// The keyboard keys that signal the end of a barcode scan (e.g. Enter, Tab).
  ///
  /// Defaults to [LogicalKeyboardKey.enter], [LogicalKeyboardKey.numpadEnter],
  /// and [LogicalKeyboardKey.tab].
  final List<LogicalKeyboardKey> terminators;

  /// Maximum time allowed between consecutive keystrokes before the buffer is
  /// discarded as human typing rather than a hardware scan.
  ///
  /// Defaults to 100 ms.
  final Duration bufferTimeout;

  /// Minimum time that must elapse between two identical scans for the second
  /// scan to be emitted. Scans within this window are rejected with
  /// [RejectionReason.deduplicated].
  ///
  /// Defaults to 500 ms.
  final Duration deduplicationWindow;

  /// The set of [BarcodeFormat] symbologies that are accepted. An empty list
  /// means all known formats are accepted.
  final List<BarcodeFormat> allowedFormats;

  /// Whether to print debug messages via [debugPrint] for each scan event.
  ///
  /// Defaults to `true`.
  final bool enableDebugLogs;

  /// Maximum number of characters the keystroke buffer will hold before
  /// being cleared as a safety guard against malfunctioning scanners.
  ///
  /// Must be between 10 and 256 characters.
  final int maxBufferLength;

  /// Creates a [BarcodeScannerConfig] with the given settings.
  const BarcodeScannerConfig({
    this.terminators = const [
      LogicalKeyboardKey.enter,
      LogicalKeyboardKey.numpadEnter,
      LogicalKeyboardKey.tab,
    ],
    this.bufferTimeout = const Duration(milliseconds: 100),
    this.deduplicationWindow = const Duration(milliseconds: 500),
    this.allowedFormats = const [],
    this.enableDebugLogs = true,
    this.maxBufferLength = 128,
  }) : assert(
         maxBufferLength >= 10 && maxBufferLength <= 256,
         'maxBufferLength must be between 10 and 256 characters. '
         'HID keyboard streaming is optimized for lightweight 1D retail barcodes; '
         'payloads exceeding 256 characters experience severe latency and timeout risks.',
       );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is BarcodeScannerConfig &&
          listEquals(terminators, other.terminators) &&
          bufferTimeout == other.bufferTimeout &&
          deduplicationWindow == other.deduplicationWindow &&
          listEquals(allowedFormats, other.allowedFormats) &&
          enableDebugLogs == other.enableDebugLogs &&
          maxBufferLength == other.maxBufferLength;

  @override
  int get hashCode => Object.hash(
        Object.hashAll(terminators),
        bufferTimeout,
        deduplicationWindow,
        Object.hashAll(allowedFormats),
        enableDebugLogs,
        maxBufferLength,
      );
}
