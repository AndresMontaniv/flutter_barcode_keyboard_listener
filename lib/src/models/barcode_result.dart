import 'barcode_format.dart';

/// Reasons a scanned or manually entered barcode may be rejected.
enum RejectionReason {
  unsupportedFormat, // String failed ALL known symbology regex patterns
  disallowedFormat,  // String matched a known format, but was NOT in allowedFormats
  deduplicated,      // Caught by the temporal deduplication shield
  empty,             // Zero characters scanned
  bufferOverflow,    // Exceeded maxBufferLength
}

/// A sealed result type representing the outcome of a barcode scan or
/// manual validation. Use exhaustive pattern matching to handle all cases.
sealed class BarcodeResult {
  final String rawValue;
  const BarcodeResult(this.rawValue);
}

/// A successfully captured barcode with its detected [format].
class BarcodeCapture extends BarcodeResult {
  final BarcodeFormat format;

  const BarcodeCapture(super.rawValue, this.format);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is BarcodeCapture &&
          rawValue == other.rawValue &&
          format == other.format;

  @override
  int get hashCode => Object.hash(rawValue, format);

  @override
  String toString() => 'BarcodeCapture($rawValue, $format)';
}

/// A rejected barcode scan with the [reason] for rejection.
class BarcodeRejection extends BarcodeResult {
  final RejectionReason reason;
  final BarcodeFormat? format;

  const BarcodeRejection(super.rawValue, this.reason, [this.format]);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is BarcodeRejection &&
          runtimeType == other.runtimeType &&
          rawValue == other.rawValue &&
          reason == other.reason &&
          format == other.format;

  @override
  int get hashCode => Object.hash(rawValue, reason, format);

  @override
  String toString() => 'BarcodeRejection(rawValue: $rawValue, reason: ${reason.name}, format:${format?.name ?? "null"})';
}
