/// Supported barcode formats and their corresponding validation patterns.
enum BarcodeFormat {
  /// **EAN-13** (Highest frequency retail)
  ///
  /// Typically used for checkout scans worldwide. Catches ~90% of checkout
  /// scans on loop 1 & 2.
  ean13(r'^\d{13}$'),

  /// **UPC-A** (Highest frequency retail)
  ///
  /// Standard 12-digit barcode format used primarily in North America.
  upcA(r'^\d{12}$'),

  /// **EAN-8** (Small retail items)
  ///
  /// Standard 8-digit barcode format used on small retail products where an
  /// EAN-13 barcode would not fit.
  ean8(r'^\d{8}$'),

  /// **UPC-E** (Small retail items)
  ///
  /// Compressed 8-digit barcode format for small items. Distinct from [ean8]
  /// when explicitly filtered in allowed formats.
  upcE(r'^\d{8}$'),

  /// **EAN-14** (Warehouse & logistics)
  ///
  /// 14-digit format typically scanned in back-rooms and warehouse logistics.
  ean14(r'^\d{14}$'),

  /// **Code 39** (Variable-length alphanumeric)
  ///
  /// A variable-length alphanumeric barcode symbology.
  ///
  /// *Note: Must always be checked last during format detection to avoid false positives.*
  code39(r'^[A-Z0-9\-\.\ \$\/\+\%]+$'),

  /// Sentinel value used when a barcode's format cannot be identified.
  unknown('');

  /// The regular expression pattern used to validate this format.
  final String pattern;

  const BarcodeFormat(this.pattern);

  // --- ZERO-ALLOCATION REGEX CACHE ---
  static final Map<BarcodeFormat, RegExp> _regexCache = {};

  /// Returns the pre-compiled [RegExp] for this format.
  ///
  /// Uses a lazy static cache to ensure the regex is compiled exactly once
  /// per app lifecycle, preventing memory churn during rapid scanning.
  RegExp get validationRegex => _regexCache.putIfAbsent(this, () => RegExp(pattern));

  /// Tests [value] against each format in [allowedFormats] and returns the
  /// first match. Returns [BarcodeFormat.unknown] if no format matches.
  static BarcodeFormat detectFormat(String value, List<BarcodeFormat> allowedFormats) {
    for (final format in allowedFormats) {
      if (format != BarcodeFormat.unknown && format.validationRegex.hasMatch(value)) {
        return format;
      }
    }
    return BarcodeFormat.unknown;
  }
}
