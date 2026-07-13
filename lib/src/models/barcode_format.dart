enum BarcodeFormat {
  upcA(r'^\d{12}$'),
  ean13(r'^\d{13}$'),
  ean8(r'^\d{8}$'),
  upcE(r'^\d{8}$'),
  code39(r'^[A-Z0-9\-\.\ \$\/\+\%]+$'),
  unknown('');

  final String pattern;

  const BarcodeFormat(this.pattern);

  RegExp get validationRegex => RegExp(pattern);

  /// Tests [value] against each format in [allowedFormats] and returns the
  /// first match. Returns [BarcodeFormat.unknown] if no format matches.
  static BarcodeFormat detectFormat(
    String value,
    List<BarcodeFormat> allowedFormats,
  ) {
    for (final format in allowedFormats) {
      if (format != BarcodeFormat.unknown &&
          format.validationRegex.hasMatch(value)) {
        return format;
      }
    }
    return BarcodeFormat.unknown;
  }
}
