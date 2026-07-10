enum BarcodeFormat {
  upcA(r'^\d{12}$'),
  upcE(r'^\d{8}$'),
  ean13(r'^\d{13}$'),
  ean8(r'^\d{8}$'),
  code39(r'^[A-Z0-9\-\.\ \$\/\+\%]+$');

  final String pattern;

  const BarcodeFormat(this.pattern);

  RegExp get validationRegex => RegExp(pattern);
}
