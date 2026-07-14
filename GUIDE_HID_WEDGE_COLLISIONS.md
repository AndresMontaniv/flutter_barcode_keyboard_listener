# Best Practices: Avoiding TextField Focus Collisions (HID Wedge Behavior)

> **💡 v1.0.1 Update:** If you are using the declarative `BarcodeKeyboardListener` widget, **Recipe 1 and Route Protection are built-in automatically!** The widget defaults to `autoPauseOnFocus: true`, which autonomously shields your background scanner from TextField collisions and navigation stack Z-index leaks.

When building inventory, POS, or warehouse applications with physical barcode scanners
(USB / Bluetooth HID), developers frequently encounter a subtle hardware-UX phenomenon:
**double-scanning when a `TextField` is focused.**

This guide explains the root cause and provides three battle-tested architectural
recipes to prevent it.

---

## The Physics of HID Wedges

Physical HID scanners act as **operating-system keyboard wedges**. When you pull the
trigger, the scanner rapidly types the barcode digits followed by an `Enter` keystroke —
indistinguishable from a human pressing keys on a physical keyboard.

If a user scans a barcode while the cursor is actively focused inside a `TextField`
(a search bar, a quantity input, a notes field), two events fire from the **same
keystroke sequence**:

| Stream | What happens |
|---|---|
| **UI stream** | The OS types the digits directly into the `TextField` and triggers its `onSubmitted` callback when the trailing `Enter` key arrives. |
| **Hardware stream** | The background library intercepts the same key-down events, buffers them, and emits a validated `BarcodeCapture` through the async broadcast stream. |

Because the library's headless `HardwareKeyboard` handler cannot distinguish human
typing from scanner bursts during active form input without hijacking normal keyboard
usage, **preventing UI duplication is strictly a presentation-layer responsibility.**

---

## Quick Decision Guide

Pick the recipe that matches your screen architecture:

| Scenario | Recommended Recipe |
|---|---|
| Imperative `BarcodeKeyboardService` · multiple or unknown text fields on screen | **Recipe 1** — Global Focus Gatekeeper |
| Declarative `BarcodeKeyboardListener` widget · one known, fixed text input | **Recipe 2** — `FocusNode` Gatekeeper |
| Cannot pause the scanner service · need a last-resort safety net | **Recipe 3** — Presentation-Layer Temporal Deduplication |

---

## Recipe 1: The Proactive Global Focus Gatekeeper

**Recommended for:** apps using the imperative `BarcodeKeyboardService` directly, or any
screen with multiple input fields where wiring individual `FocusNode` instances would
create boilerplate.

Register a single listener on Flutter's global `FocusManager`. Whenever *any* text input
on the screen gains focus, imperatively pause the hardware handler before the first
keystroke can be injected. When focus leaves, resume instantly.

### Why `findAncestorWidgetOfExactType<EditableText>()` and not `widget is EditableText`

Flutter's text widgets (`TextField`, `TextFormField`, `CupertinoTextField`) do **not**
attach the `FocusNode` directly to `EditableText`. Inside `EditableText.build()`, the
framework wraps its contents in a generic `Focus` widget:

```dart
// Flutter framework internals (simplified)
@override
Widget build(BuildContext context) {
  return Focus(
    focusNode: widget.focusNode,  // ← FocusNode lives here
    child: ...,
  );
}
```

This means `FocusManager.instance.primaryFocus?.context?.widget` resolves to `Focus`
(or `_FocusMarker`), **not** `EditableText`. A direct `is EditableText` check will always
return `false`.

Because `EditableText` is the immediate **parent** of that internal `Focus` node in the
element tree, walking one level up with `findAncestorWidgetOfExactType<EditableText>()`
correctly identifies any active text input — without false positives from buttons,
`ListTile`s, or `Switch`es.

### Implementation

```dart
class _MyScanScreenState extends State<MyScanScreen> {
  late final BarcodeKeyboardService _service;
  late final StreamSubscription<BarcodeCapture> _captureSub;
  late final StreamSubscription<BarcodeRejection> _rejectionSub;

  @override
  void initState() {
    super.initState();

    _service = BarcodeKeyboardService(
      const BarcodeScannerConfig(
        allowedFormats: [BarcodeFormat.ean13, BarcodeFormat.ean8],
      ),
    );

    _captureSub   = _service.barcodeStream.listen(_onCapture);
    _rejectionSub = _service.rejectionStream.listen(_onRejection);

    // Register BEFORE start() so the gatekeeper is active from the first scan.
    FocusManager.instance.addListener(_onGlobalFocusChanged);

    _service.start();
  }

  /// Pauses or resumes the hardware handler based on whether any [EditableText]
  /// (the internal engine of [TextField] / [TextFormField]) is currently focused.
  ///
  /// We walk up the element tree with [BuildContext.findAncestorWidgetOfExactType]
  /// because Flutter's focus system attaches the [FocusNode] to an internal
  /// [Focus] widget *inside* [EditableText], not to [EditableText] itself.
  void _onGlobalFocusChanged() {
    final focus = FocusManager.instance.primaryFocus;

    final isTextFieldActive =
        focus?.context?.findAncestorWidgetOfExactType<EditableText>() != null ||
        focus?.context?.widget is EditableText;

    if (isTextFieldActive) {
      _service.stop();
    } else {
      _service.start();
    }
  }

  void _onCapture(BarcodeCapture capture) {
    // Handle validated scan result.
  }

  void _onRejection(BarcodeRejection rejection) {
    // Handle rejected scan.
  }

  @override
  void dispose() {
    // Always remove the listener before disposing the service.
    FocusManager.instance.removeListener(_onGlobalFocusChanged);
    _captureSub.cancel();
    _rejectionSub.cancel();
    _service.dispose();
    super.dispose();
  }
}
```

---

## Recipe 2: The `FocusNode` Gatekeeper

**Recommended for:** apps using the declarative `BarcodeKeyboardListener` widget with
one specific, known text input (a dedicated manual-entry field or a single search bar).

Bind a `FocusNode` to the target `TextField` and pass its inverted focus state to the
widget's `enabled` property. The widget's `didUpdateWidget` lifecycle hook will call
`stop()` or `start()` on the underlying service automatically — no manual service
management required.

```dart
class _MyScanScreenState extends State<MyScanScreen> {
  final FocusNode _inputFocus = FocusNode();
  bool _isScannerEnabled = true;

  @override
  void initState() {
    super.initState();
    // Trigger a rebuild on every focus change so the `enabled` expression
    // re-evaluates and the widget wrapper pauses or resumes accordingly.
    _inputFocus.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _inputFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BarcodeKeyboardListener(
      // The widget automatically calls stop() when enabled flips to false
      // and start() when it flips back to true — no stream wiring needed.
      enabled: _isScannerEnabled && !_inputFocus.hasFocus,
      onBarcodeScanned: (capture) {
        // Handle validated scan result.
      },
      onBarcodeRejected: (rejection) {
        // Handle rejected scan.
      },
      child: Scaffold(
        body: TextField(
          focusNode: _inputFocus,
          decoration: const InputDecoration(labelText: 'Manual Entry'),
        ),
      ),
    );
  }
}
```

> **Scaling note:** If your screen has two or three known inputs, create a `FocusNode`
> per field and combine them:
> `enabled: !_fieldA.hasFocus && !_fieldB.hasFocus`.
> For four or more fields, switch to Recipe 1 to avoid boilerplate.

---

## Recipe 3: Presentation-Layer Temporal Deduplication

**Recommended as a last resort** for screens where pausing the scanner service is not
acceptable (e.g., a high-throughput receiving station where the scanner must always be
active), or as an additional safety net layered on top of Recipes 1 or 2.

Apply a UI-level deduplication shield in the state callback that processes both hardware
stream captures and manual `TextField` submissions. If the same barcode value arrives
twice within a short window, discard the duplicate before it reaches the history list.

```dart
DateTime? _lastUiScanTime;
String?   _lastUiScanCode;

/// Processes a scan result from either the hardware stream or a manual
/// TextField submission, deduplicating same-value entries within 500 ms.
void _processAnyCapture(String rawValue) {
  final now = DateTime.now();

  if (_lastUiScanCode == rawValue &&
      _lastUiScanTime != null &&
      now.difference(_lastUiScanTime!) < const Duration(milliseconds: 500)) {
    // Same barcode within the deduplication window — discard the duplicate.
    return;
  }

  _lastUiScanCode = rawValue;
  _lastUiScanTime = now;

  setState(() {
    _scanHistory.insert(0, rawValue);
  });
}
```

> **Edge-case awareness:** This shield deduplicates only when the *same* barcode value
> arrives twice in quick succession — which is precisely the double-scan scenario. Two
> *different* barcodes scanned in rapid succession will both be recorded correctly and
> are unaffected by this logic.

---

### Recipe 4: IndexedStack & Tabbed Navigation (The Route Guard)
When using an `IndexedStack` or a `GoRouter` `StatefulShellRoute`, multiple screens remain alive in memory simultaneously. Standard `initState()` and `dispose()` hooks do not fire when switching tabs. 

To prevent a background tab from stealing your hardware scans, bind the `enabled` property of the `BarcodeKeyboardListener` to your navigation state:

```dart
@override
Widget build(BuildContext context) {
  // Example: Watch your BottomNavCubit or GoRouter state
  final currentNavIndex = context.watch<BottomNavCubit>().state.selectedIndex;
  final isThisTabActive = currentNavIndex == 1; // 1 = Inventory Tab

  return BarcodeKeyboardListener(
    // Gate the scanner: Only listen if this specific tab is visually active!
    enabled: isThisTabActive,
    onBarcodeScanned: (capture) => _lookupInventory(capture.rawValue),
    child: Scaffold( ... ),
  );
}
```

---

## Summary

| Recipe | Mechanism | Scanner paused at source? | Boilerplate |
|---|---|---|---|
| **1 · Global Focus Gatekeeper** | `FocusManager` listener + `stop()`/`start()` | ✅ Yes | Minimal |
| **2 · `FocusNode` Gatekeeper** | `FocusNode` listener + `enabled` prop | ✅ Yes | Low (one node per field) |
| **3 · Temporal Deduplication** | UI-level timestamp shield | ❌ No | Minimal |

Recipes 1 and 2 are the correct architectural solutions because they prevent the library
from emitting duplicate events in the first place. Recipe 3 is a complementary safety
layer, not a replacement.
