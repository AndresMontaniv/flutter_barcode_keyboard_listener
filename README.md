# Barcode HID Listener

[![Pub Version](https://img.shields.io/pub/v/barcode_hid_listener)](https://pub.dev/packages/barcode_hid_listener)
[![Pub Points](https://img.shields.io/pub/points/barcode_hid_listener)](https://pub.dev/packages/barcode_hid_listener/score)
[![Flutter Platform](https://img.shields.io/badge/Platform-Flutter-02569B?logo=flutter)](https://flutter.dev)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](https://opensource.org/licenses/MIT)

A headless, zero-dependency Flutter package for intercepting, buffering, and validating physical HID barcode scanner keystrokes (USB/Bluetooth). 

Designed for enterprise Retail POS, Warehouse Inventory, and Logistics applications, this package catches raw hardware keystrokes in the background and transforms them into clean, strongly-typed Dart streams—without requiring any native OS plugins.

## ✨ Features

- 🛡️ **Two-Stage Symbology Gatekeeper:** Built-in Regex validation for global retail and logistics formats (UPC, EAN, Code 39).
- ⏱️ **Temporal Deduplication:** Automatically ignores accidental double-scans within a configurable time window.
- 🔄 **GS1 AI Normalization:** Automatically intercepts and strips the `01` Application Identifier prefix from 16-digit hardware EAN-14 scans.
- 🚀 **Dual Paradigm:** Drop in a simple, declarative UI `Widget`, or run the headless `Service` inside your Riverpod/Bloc state controllers.
- 🚫 **Zero Dependencies:** Pure Dart. Runs flawlessly on iOS, Android, Windows, macOS, Linux, and Web.

---

## 📦 Installation

Add it to your `pubspec.yaml`:

```bash
flutter pub add barcode_hid_listener

```

---

## 💻 Usage

We provide two distinct ways to integrate barcode listening into your app depending on your architectural needs.

### Option 1: The Declarative Widget Wrapper (Recommended for UI)

Wrap your screen or specific widget tree with `BarcodeKeyboardListener`. Focus management and route-visibility are handled automatically!

```dart
BarcodeKeyboardListener(
  // autoPauseOnFocus is true by default. The scanner will automatically 
  // pause if the user taps into a TextField!
  onBarcodeScanned: (capture) {
    print("Scanned: ${capture.rawValue}");
  },
  child: Scaffold(
    body: TextField(
      decoration: InputDecoration(labelText: 'Manual Entry (Scanner pauses while typing)'),
    ),
  ),
);
```

### Option 2: The Imperative Service (For Advanced State Management)

If you are managing background streams inside a View Model, Bloc, or Riverpod Provider, you can instantiate the headless service directly.

```dart
import 'package:barcode_hid_listener/barcode_hid_listener.dart';

// 1. Initialize Configuration
final config = BarcodeScannerConfig(
  allowedFormats: BarcodeFormat.values,
  deduplicationWindow: const Duration(milliseconds: 500),
);

// 2. Instantiate Service
final service = BarcodeKeyboardService(config);

// 3. Listen to Streams
service.barcodeStream.listen((capture) {
  print('Success! GTIN: ${capture.rawValue}');
});

service.rejectionStream.listen((rejection) {
  print('Blocked: ${rejection.reason.name}');
});

// 4. Start Listening (Don't forget to call service.dispose() when done!)
service.start();

```

---

## ⚙️ Configuration & Symbologies

### `BarcodeScannerConfig`

You can tailor the hardware ingestion engine to your specific hardware environments using the `BarcodeScannerConfig` object:

| Property | Default | Description |
| --- | --- | --- |
| `terminators` | `[LogicalKeyboardKey.enter]` | Hardware keystrokes signaling the end of a scan. |
| `bufferTimeout` | `100ms` | Maximum elapsed time between keystrokes before the buffer resets. Filters out slow human typing. |
| `deduplicationWindow` | `500ms` | Time window where identical back-to-back scans are ignored. |
| `allowedFormats` | `[]` *(All)* | Whitelist of allowed symbologies. Unlisted formats are cleanly blocked. |

### Supported `BarcodeFormat` Values

The Two-Stage Gatekeeper currently detects and routes the following global standards:

* `ean13` (Standard retail items)
* `upcA` (North American retail items)
* `ean8` (Small retail items)
* `upcE` (Small North American retail items)
* `ean14` / GTIN-14 (Outer cases and warehouse pallets)
* `code39` (Alphanumeric inventory badges and asset tags)

---

## 💡 Best Practices & Troubleshooting

### Preventing TextField Focus Collisions (HID Wedge Behavior)

Because physical USB/Bluetooth HID scanners act as operating system keyboards, scanning a barcode while a `TextField` (like a search bar or manual input form) is focused can cause duplicate keystroke events between your active UI text field and the background hardware stream.

We provide 3 simple presentation-layer recipes (`FocusNode` Gatekeeping, Global Focus Shielding, and UI Deduplication) to handle this effortlessly in your app.

👉 **[Read the authoritative guide on avoiding HID Wedge Focus Collisions. The file is on the root of the project "GUIDE_HID_WEDGE_COLLISIONS.md".](GUIDE_HID_WEDGE_COLLISIONS.md)**

---

## 🐛 Bugs and 🤝 Contributing

We highly encourage you to report any malfunctions, bugs, or feature recommendations! 

Please do not hesitate to leave an issue on our [GitHub Issues page](https://github.com/AndresMontaniv/flutter_barcode_hid_listener/issues). 

## 🤝 Acknowledgments

This package was inspired by the design philosophy of [flutter_barcode_listener](https://pub.dev/packages/flutter_barcode_listener). 

We built `barcode_hid_listener` as a modern, null-safe evolution because the original implementation relied on deprecated APIs (such as `RawKeyboard.instance`). Our version has been completely rewritten to utilize the modern `HardwareKeyboard.instance` event API, ensuring long-term compatibility with current and future Flutter versions, and adds enterprise-grade features like GS1 normalization, Two-Stage symbology gatekeeping, and proactive focus-shielding.

