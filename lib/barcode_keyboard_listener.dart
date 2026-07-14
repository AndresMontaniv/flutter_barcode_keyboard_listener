/// A headless, zero-dependency Flutter package for intercepting, buffering,
/// and validating physical HID barcode scanner keystrokes.
///
/// Provides temporal deduplication, symbology gatekeeping (UPC, EAN, Code 39),
/// and rich stream-based error reporting without requiring native OS plugins.
library;

export 'src/models/barcode_format.dart';
export 'src/models/barcode_result.dart';
export 'src/models/barcode_scanner_config.dart';
export 'src/services/barcode_keyboard_service.dart';
export 'src/widgets/barcode_keyboard_listener.dart';
