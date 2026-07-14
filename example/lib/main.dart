import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart' show CupertinoIcons;

import 'package:barcode_hid_listener/barcode_hid_listener.dart';

import 'widget_wrapper_screen.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Barcode Scanner Test',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: const ScannerTestScreen(),
    );
  }
}

// ---------------------------------------------------------------------------
// ScannerTestScreen – proves headless BarcodeKeyboardService integration.
// ---------------------------------------------------------------------------

class ScannerTestScreen extends StatefulWidget {
  const ScannerTestScreen({super.key});

  @override
  State<ScannerTestScreen> createState() => _ScannerTestScreenState();
}

class _ScannerTestScreenState extends State<ScannerTestScreen> {
  // ── Service & subscription ──────────────────────────────────────────────
  late final BarcodeKeyboardService _barcodeService;
  late final StreamSubscription<BarcodeCapture> _barcodeSubscription;
  late final StreamSubscription<BarcodeRejection> _rejectionSubscription;

  // ── UI state ────────────────────────────────────────────────────────────
  String _recentBarcode = '—';
  String _lastRejection = '';
  final List<(BarcodeResult, DateTime)> _scanHistory = [];

  // ── Manual entry ────────────────────────────────────────────────────────
  final TextEditingController _manualController = TextEditingController();

  // ── Lifecycle ───────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();

    // 1. Build config – allow all format by leaving empty list.
    const config = BarcodeScannerConfig(
      allowedFormats: [
        BarcodeFormat.ean13,
        BarcodeFormat.ean8,
        BarcodeFormat.upcA,
        BarcodeFormat.ean14,
      ],
    );

    // 2. Instantiate the service.
    _barcodeService = BarcodeKeyboardService(config);

    // 3. Subscribe to the barcode stream.
    _barcodeSubscription = _barcodeService.barcodeStream.listen(_processCapture);

    // 4. Subscribe to the rejection stream.
    _rejectionSubscription = _barcodeService.rejectionStream.listen(_processRejection);

    // 5. PROACTIVE GLOBAL FOCUS GATEKEEPER
    //    Listen to global focus changes. If any EditableText (the inner engine
    //    of TextField / TextFormField) gains focus, proactively pause background
    //    hardware listening so the UI input form can handle the HID keystrokes
    //    without duplicate stream events. Covers every text input on the screen
    //    without wiring individual FocusNodes.
    FocusManager.instance.addListener(_onGlobalFocusChanged);

    // 6. Start listening to HardwareKeyboard.
    _barcodeService.start();
  }

  /// Reacts to global focus changes by pausing or resuming the hardware
  /// keyboard handler based on whether an [EditableText] is focused.
  void _onGlobalFocusChanged() {
    // --- ROUTE VISIBILITY GUARD ---
    // If this screen is covered by another pushed screen (like WidgetWrapperScreen),
    // ignore global focus shifts so we don't steal hardware ownership from the active route!
    if (ModalRoute.of(context)?.isCurrent != true) return;

    final focus = FocusManager.instance.primaryFocus;

    final isTextFieldActive = focus?.context?.findAncestorWidgetOfExactType<EditableText>() != null || focus?.context?.widget is EditableText;

    if (isTextFieldActive) {
      _barcodeService.stop();
    } else {
      _barcodeService.start();
    }
  }

  @override
  void dispose() {
    FocusManager.instance.removeListener(_onGlobalFocusChanged);
    _barcodeSubscription.cancel();
    _rejectionSubscription.cancel();
    _barcodeService.dispose();
    _manualController.dispose();
    super.dispose();
  }

  // ── Barcode processing ─────────────────────────────────────────────────

  void _addToHistory(BarcodeResult result) {
    _scanHistory.insert(0, (result, DateTime.now()));
  }

  void _processCapture(BarcodeCapture capture) {
    setState(() {
      _recentBarcode = '${capture.rawValue} (${capture.format.name})';
      _lastRejection = '';
      _addToHistory(capture);
    });
  }

  void _processRejection(BarcodeRejection rejection) {
    const int maxDisplayLength = 20;
    String rawValue = rejection.rawValue;
    if (rawValue.length > maxDisplayLength) {
      rawValue = '${rawValue.substring(0, maxDisplayLength)}…';
    }
    final formatLabel = rejection.format?.name.toUpperCase() ?? 'UNSUPPORTED';
    setState(() {
      _recentBarcode = '${rejection.rawValue} ($formatLabel)';
      _lastRejection = '$rawValue -> (${rejection.reason.name})';
      _addToHistory(rejection);
    });
  }

  void _onManualSubmit() {
    final text = _manualController.text.trim();
    if (text.isEmpty) return;

    // Pass the same allowedFormats configured in our service
    final result = _validateManualInput(text, [
      BarcodeFormat.ean13,
      BarcodeFormat.ean8,
      BarcodeFormat.upcA,
      BarcodeFormat.ean14,
    ]);

    switch (result) {
      case BarcodeCapture():
        _processCapture(result);
      case BarcodeRejection():
        _processRejection(result);
    }
    _manualController.clear();
  }

  /// Validates a manually entered barcode string against [allowedFormats],
  /// mirroring the hardware-wedge normalization performed by [BarcodeKeyboardService].
  BarcodeResult _validateManualInput(String rawValue, List<BarcodeFormat> allowedFormats) {
    if (rawValue.isEmpty) {
      return const BarcodeRejection('', RejectionReason.empty);
    }

    var code = rawValue.trim();

    // --- GS1 AI NORMALIZATION ---
    // Strip the 2-digit '01' Application Identifier from 16-digit EAN-14 codes
    // to match the hardware wedge normalization behavior.
    if (code.length == 16 && code.startsWith('01')) {
      code = code.substring(2);
    }

    // Stage 1: Check against allowed formats
    final allowedToTest = allowedFormats.isNotEmpty ? allowedFormats : BarcodeFormat.values;
    final allowedFormat = BarcodeFormat.detectFormat(code, allowedToTest);

    if (allowedFormat != BarcodeFormat.unknown) {
      return BarcodeCapture(code, allowedFormat);
    }

    // Stage 2: Check if it's a known but disallowed format
    if (allowedFormats.isNotEmpty) {
      final knownFormat = BarcodeFormat.detectFormat(code, BarcodeFormat.values);
      if (knownFormat != BarcodeFormat.unknown) {
        return BarcodeRejection(code, RejectionReason.disallowedFormat, knownFormat);
      }
    }

    return BarcodeRejection(code, RejectionReason.unsupportedFormat, BarcodeFormat.unknown);
  }

  // ── Build ──────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Imperative Service Mode'),
        backgroundColor: theme.colorScheme.inversePrimary,
        actions: [
          TextButton.icon(
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const WidgetWrapperScreen(),
                ),
              );
            },
            icon: const Icon(Icons.widgets_outlined),
            label: const Text('Widget Mode'),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── Dashboard card ──────────────────────────────────────────
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Dashboard', style: theme.textTheme.titleLarge),
                    const SizedBox(height: 12),
                    Text('Recent barcode:', style: theme.textTheme.labelMedium),
                    const SizedBox(height: 4),
                    SelectableText(
                      _recentBarcode,
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontFamily: 'monospace',
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Total scans: ${_scanHistory.length}',
                      style: theme.textTheme.bodyLarge,
                    ),
                    if (_lastRejection.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text(
                        'Last rejection: $_lastRejection',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.error,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // ── Manual entry ────────────────────────────────────────────
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _manualController,
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      labelText: 'Manual barcode entry',
                      hintText: 'Type a barcode and press Submit',
                    ),
                    onSubmitted: (_) => _onManualSubmit(),
                  ),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  onPressed: _onManualSubmit,
                  child: const Text('Submit'),
                ),
              ],
            ),

            const SizedBox(height: 16),

            // ── Scan history ────────────────────────────────────────────
            Text('Scan History', style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            Expanded(
              child: _scanHistory.isEmpty
                  ? Center(
                      child: Text(
                        'No scans yet.\n'
                        'Use a barcode scanner or enter one manually.',
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    )
                  : ListView.separated(
                      itemCount: _scanHistory.length,
                      separatorBuilder: (_, _) => const Divider(height: 1),
                      itemBuilder: (context, index) {
                        final (record, timestamp) = _scanHistory[index];
                        switch (record) {
                          case BarcodeCapture():
                            return ListTile(
                              leading: const Icon(
                                CupertinoIcons.barcode,
                                color: Colors.black,
                                size: 35,
                              ),
                              title: Text(
                                record.rawValue,
                                style: const TextStyle(fontFamily: 'monospace'),
                              ),
                              subtitle: Text(
                                record.format.name.toUpperCase(),
                                style: TextStyle(color: theme.colorScheme.primary, fontWeight: FontWeight.w600),
                              ),
                              trailing: Text(_formatTimestamp(timestamp)),
                            );
                          case BarcodeRejection():
                            final format = record.format?.name.toUpperCase();
                            final subtitle = format != null ? '$format (${record.reason.name})' : record.reason.name;
                            return ListTile(
                              leading: const Icon(
                                Icons.disabled_by_default_outlined,
                                color: Colors.redAccent,
                                size: 35,
                              ),
                              title: Text(
                                record.rawValue,
                                style: const TextStyle(
                                  fontFamily: 'monospace',
                                  overflow: TextOverflow.ellipsis,
                                ),
                                maxLines: 1,
                              ),
                              subtitle: Text(
                                subtitle,
                                style: const TextStyle(
                                  color: Colors.red,
                                  fontSize: 11,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                maxLines: 2,
                              ),
                              trailing: Text(_formatTimestamp(timestamp)),
                            );
                        }
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Helpers ────────────────────────────────────────────────────────────

  String _formatTimestamp(DateTime dt) {
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    final s = dt.second.toString().padLeft(2, '0');
    return '$h:$m:$s';
  }
}
