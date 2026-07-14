import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import '../models/barcode_format.dart';
import '../models/barcode_result.dart';
import '../models/barcode_scanner_config.dart';

const _gs1Prefix = '01';

/// A headless service that intercepts raw system keystrokes via
/// [HardwareKeyboard], assembles them into a buffer, validates against
/// configured [BarcodeFormat] symbologies, and emits deduplicated
/// [BarcodeCapture] objects through a broadcast [Stream].
///
/// Rejected scans are emitted on a secondary [rejectionStream].
///
/// A pure Dart service that intercepts OS-level hardware keystrokes.
///
/// This service must be instantiated outside the widget tree. It guarantees
/// exclusive ownership of the [HardwareKeyboard.instance] handler to prevent
/// memory leaks and simultaneous global stream collisions.
class BarcodeKeyboardService {
  final BarcodeScannerConfig config;

  /// Class-level tracker: only one instance may own the HardwareKeyboard
  /// handler at any time. Calling [start] on a new instance automatically
  /// pauses the previous instance's handler.
  static BarcodeKeyboardService? _activeInstance;

  final StreamController<BarcodeCapture> _controller = StreamController<BarcodeCapture>.broadcast();
  final StreamController<BarcodeRejection> _rejectionController = StreamController<BarcodeRejection>.broadcast();
  final StringBuffer _buffer = StringBuffer();
  bool _isRunning = false;
  DateTime? _lastEventTime;
  DateTime? _lastScannedTime;
  String? _lastScannedCode;

  /// Creates a [BarcodeKeyboardService] with the given [config].
  BarcodeKeyboardService(this.config);

  /// A broadcast stream of validated, deduplicated [BarcodeCapture] results.
  Stream<BarcodeCapture> get barcodeStream => _controller.stream;

  /// A broadcast stream of [BarcodeRejection] results for scans that failed
  /// validation or were deduplicated.
  Stream<BarcodeRejection> get rejectionStream => _rejectionController.stream;

  /// Begins intercepting hardware keystrokes.
  /// 
  /// This method is idempotent. Calling it multiple times will safely 
  /// enforce exclusive handler ownership without duplicating listeners.
  void start() {
    if (_isRunning) return;

    // --- EXCLUSIVE HANDLER GUARD ---
    // If another service instance is currently active, stop it first
    // to prevent duplicate global stream broadcasts across hidden tabs.
    if (_activeInstance != null && _activeInstance != this) {
      _activeInstance!.stop();
    }

    _isRunning = true;
    _activeInstance = this;
    HardwareKeyboard.instance.addHandler(_handleKeyEvent);
  }

  /// Safely detaches from the global keyboard stream.
  /// 
  /// Must be called during the teardown phase of the consuming Cubit or Provider
  /// to ensure cleanly disposed stream subscriptions.
  void stop() {
    if (!_isRunning) return;
    _isRunning = false;
    
    // Release static ownership if this instance was the active one
    if (_activeInstance == this) {
      _activeInstance = null;
    }
    
    HardwareKeyboard.instance.removeHandler(_handleKeyEvent);
  }

  /// Whether this specific service instance currently owns the global keyboard handler.
  bool get isActive => _activeInstance == this;

  /// Removes the keyboard handler and closes both stream controllers.
  void dispose() {
    stop();
    _controller.close();
    _rejectionController.close();
  }

  /// Emits a [BarcodeRejection] on the rejection stream, logs if debug is
  /// enabled, and returns `false` so callers can `return _emitRejection(…)`.
  bool _emitRejection(
    String code,
    RejectionReason reason, [
    BarcodeFormat? format,
  ]) {
    final rejection = BarcodeRejection(code, reason, format);
    _rejectionController.sink.add(rejection);
    if (config.enableDebugLogs) {
      debugPrint('[BarcodeKeyboardService] Rejected (${reason.name}): $code');
    }
    return false;
  }

  bool _handleKeyEvent(KeyEvent event) {
    // Only process key-down events.
    if (event is! KeyDownEvent) return false;

    final now = DateTime.now();

    // Timeout guard: if too much time elapsed since the last keystroke,
    // the buffer contains human typing – purge it.
    if (_lastEventTime != null && now.difference(_lastEventTime!) > config.bufferTimeout) {
      _buffer.clear();
    }
    _lastEventTime = now;

    // Check if this keystroke is a configured terminator (scan complete).
    if (config.terminators.contains(event.logicalKey)) {
      var scannedCode = _buffer.toString();
      _buffer.clear();

      if (scannedCode.isEmpty) return false;

      // --- GS1 AI NORMALIZATION PRE-PROCESSOR ---
      // If a warehouse EAN-14 arrives with the GS1 Application Identifier '01'
      // (16 numeric digits total), strip the '01' prefix so the gatekeeper and
      // downstream consumers always receive a consistent 14-digit GTIN.
      if (scannedCode.length == 16 && scannedCode.startsWith(_gs1Prefix)) {
        scannedCode = scannedCode.substring(_gs1Prefix.length);
      }

      // 1. Stage 1: Check if the barcode matches an ALLOWED format.
      final allowedToTest = config.allowedFormats.isNotEmpty ? config.allowedFormats : BarcodeFormat.values;

      final allowedFormat = BarcodeFormat.detectFormat(
        scannedCode,
        allowedToTest,
      );

      if (allowedFormat != BarcodeFormat.unknown) {
        // 2. Deduplication Shield
        if (_lastScannedCode == scannedCode && _lastScannedTime != null && now.difference(_lastScannedTime!) < config.deduplicationWindow) {
          return _emitRejection(
            scannedCode,
            RejectionReason.deduplicated,
            allowedFormat,
          );
        }

        // 3. Emit Success
        _lastScannedCode = scannedCode;
        _lastScannedTime = now;
        _controller.sink.add(BarcodeCapture(scannedCode, allowedFormat));
        return false;
      }

      // 4. Stage 2: It failed the allowed list. Is it a KNOWN format that was disallowed?
      if (config.allowedFormats.isNotEmpty) {
        final knownFormat = BarcodeFormat.detectFormat(
          scannedCode,
          BarcodeFormat.values,
        );
        if (knownFormat != BarcodeFormat.unknown) {
          return _emitRejection(
            scannedCode,
            RejectionReason.disallowedFormat,
            knownFormat,
          );
        }
      }

      // 5. Complete Failure: Unsupported symbology or corrupted string.
      return _emitRejection(
        scannedCode,
        RejectionReason.unsupportedFormat,
        null,
      );
    } else {
      // Buffer overflow guard: clear and reject if a malfunctioning scanner
      // streams excessive data.
      if (_buffer.length >= config.maxBufferLength) {
        _buffer.clear();
        return _emitRejection(
          event.character ?? 'OVERFLOW',
          RejectionReason.bufferOverflow,
          null,
        );
      }

      // Ongoing scan – accumulate printable characters.
      final character = event.character;
      if (character != null && character.isNotEmpty) {
        _buffer.write(character);
      }
    }

    return false;
  }
}
