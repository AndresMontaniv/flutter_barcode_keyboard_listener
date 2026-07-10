import 'dart:async';

import 'package:barcode_keyboard_listener/barcode_keyboard_listener.dart';
import 'package:flutter/material.dart';

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
// Data model for a single scan record.
// ---------------------------------------------------------------------------

class ScanRecord {
  final String barcode;
  final DateTime timestamp;

  const ScanRecord({required this.barcode, required this.timestamp});
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
  late final StreamSubscription<String> _barcodeSubscription;

  // ── UI state ────────────────────────────────────────────────────────────
  String _recentBarcode = '—';
  int _totalScans = 0;
  final List<ScanRecord> _scanHistory = [];

  // ── Manual entry ────────────────────────────────────────────────────────
  final TextEditingController _manualController = TextEditingController();

  // ── Lifecycle ───────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();

    // 1. Build config – allow EAN-13 and UPC-A for testing.
    const config = BarcodeScannerConfig(
      allowedFormats: [BarcodeFormat.ean13, BarcodeFormat.upcA, BarcodeFormat.ean8],
    );

    // 2. Instantiate the service.
    _barcodeService = BarcodeKeyboardService(config);

    // 3. Start listening to HardwareKeyboard.
    _barcodeService.start();

    // 4. Subscribe to the barcode stream.
    _barcodeSubscription = _barcodeService.barcodeStream.listen(
      _processBarcode,
    );
  }

  @override
  void dispose() {
    _barcodeSubscription.cancel();
    _barcodeService.dispose();
    _manualController.dispose();
    super.dispose();
  }

  // ── Barcode processing ─────────────────────────────────────────────────

  void _processBarcode(String code) {
    setState(() {
      _recentBarcode = code;
      _totalScans++;
      _scanHistory.insert(
        0,
        ScanRecord(barcode: code, timestamp: DateTime.now()),
      );
    });
  }

  void _onManualSubmit() {
    final text = _manualController.text.trim();
    if (text.isEmpty) return;

    _processBarcode(text);
    _manualController.clear();
  }

  // ── Build ──────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Barcode Scanner Test'),
        backgroundColor: theme.colorScheme.inversePrimary,
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
                      'Total scans: $_totalScans',
                      style: theme.textTheme.bodyLarge,
                    ),
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
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (context, index) {
                        final record = _scanHistory[index];
                        return ListTile(
                          leading: const Icon(Icons.qr_code_2),
                          title: Text(
                            record.barcode,
                            style: const TextStyle(fontFamily: 'monospace'),
                          ),
                          subtitle: Text(_formatTimestamp(record.timestamp)),
                          trailing: Text(
                            '#${_scanHistory.length - index}',
                            style: theme.textTheme.labelSmall,
                          ),
                        );
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
