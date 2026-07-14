import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:barcode_hid_listener/barcode_hid_listener.dart';

class WidgetWrapperScreen extends StatefulWidget {
  const WidgetWrapperScreen({super.key});

  @override
  State<WidgetWrapperScreen> createState() => _WidgetWrapperScreenState();
}

class _WidgetWrapperScreenState extends State<WidgetWrapperScreen> {
  // ── UI state ────────────────────────────────────────────────────────────
  String _recentBarcode = '—';
  String _lastRejection = '';
  bool _isListeningEnabled = true; // Proves dynamic reactivity!
  final List<(BarcodeResult, DateTime)> _scanHistory = [];

  // ── Manual entry controller ─────────────────────────────────────────────
  final TextEditingController _manualController = TextEditingController();

  // ── Configuration ───────────────────────────────────────────────────────
  static const _allowedFormats = [
    BarcodeFormat.ean13,
    BarcodeFormat.ean8,
    BarcodeFormat.upcA,
    BarcodeFormat.ean14,
  ];

  static const _config = BarcodeScannerConfig(
    allowedFormats: _allowedFormats,
    enableDebugLogs: true,
  );

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    _manualController.dispose();
    // Notice: No service or stream subscriptions to cancel!
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
    var rawValue = rejection.rawValue;
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

  // Local presentation helper for manual form entry
  BarcodeResult _validateManualInput(String rawValue) {
    if (rawValue.isEmpty) {
      return const BarcodeRejection('', RejectionReason.empty);
    }

    var code = rawValue.trim();

    // GS1 AI Normalization Parity
    if (code.length == 16 && code.startsWith('01')) {
      code = code.substring(2);
    }

    final allowedFormat = BarcodeFormat.detectFormat(code, _allowedFormats);
    if (allowedFormat != BarcodeFormat.unknown) {
      return BarcodeCapture(code, allowedFormat);
    }

    final knownFormat = BarcodeFormat.detectFormat(code, BarcodeFormat.values);
    if (knownFormat != BarcodeFormat.unknown) {
      return BarcodeRejection(code, RejectionReason.disallowedFormat, knownFormat);
    }

    return BarcodeRejection(code, RejectionReason.unsupportedFormat, BarcodeFormat.unknown);
  }

  void _onManualSubmit() {
    final text = _manualController.text.trim();
    if (text.isEmpty) return;

    final result = _validateManualInput(text);
    switch (result) {
      case BarcodeCapture():
        _processCapture(result);
      case BarcodeRejection():
        _processRejection(result);
    }
    _manualController.clear();
  }

  // ── Build ──────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // Wrap the entire screen (or body) in the declarative listener!
    return BarcodeKeyboardListener(
      config: _config,
      // No need to check FocusNode! autoPauseOnFocus is true by default.
      enabled: _isListeningEnabled,
      onBarcodeScanned: _processCapture,
      onBarcodeRejected: _processRejection,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Declarative Widget Mode'),
          backgroundColor: theme.colorScheme.tertiaryContainer,
        ),
        body: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ── Dashboard card with Enabled Toggle ──────────────────
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Dashboard', style: theme.textTheme.titleLarge),
                          Row(
                            children: [
                              Text(
                                _isListeningEnabled ? 'Listening' : 'Paused',
                                style: theme.textTheme.labelMedium?.copyWith(
                                  color: _isListeningEnabled
                                      ? theme.colorScheme.primary
                                      : theme.colorScheme.error,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Switch(
                                value: _isListeningEnabled,
                                onChanged: (val) => setState(() => _isListeningEnabled = val),
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
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

              // ── Manual entry ────────────────────────────────────────
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

              // ── Scan history ────────────────────────────────────────
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
                                leading: Icon(
                                  CupertinoIcons.barcode,
                                  color: theme.colorScheme.onSurface,
                                  size: 35,
                                ),
                                title: Text(
                                  record.rawValue,
                                  style: const TextStyle(fontFamily: 'monospace'),
                                ),
                                subtitle: Text(
                                  record.format.name.toUpperCase(),
                                  style: TextStyle(
                                    color: theme.colorScheme.primary,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                trailing: Text(_formatTimestamp(timestamp)),
                              );
                            case BarcodeRejection():
                              final isDisallowed = record.reason == RejectionReason.disallowedFormat;
                              final isDeduplicated = record.reason == RejectionReason.deduplicated;

                              final Color badgeColor = isDisallowed
                                  ? theme.colorScheme.tertiary
                                  : isDeduplicated
                                      ? theme.colorScheme.outline
                                      : theme.colorScheme.error;

                              final String reasonLabel = isDisallowed
                                  ? 'BLOCKED FORMAT (${record.format?.name.toUpperCase() ?? "UNKNOWN"})'
                                  : isDeduplicated
                                      ? 'DEDUPLICATED (IGNORED)'
                                      : 'UNSUPPORTED SYMBOLOGY';

                              return ListTile(
                                leading: Icon(
                                  Icons.disabled_by_default_outlined,
                                  color: badgeColor,
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
                                  reasonLabel,
                                  style: TextStyle(
                                    color: badgeColor,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
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
      ),
    );
  }

  String _formatTimestamp(DateTime dt) {
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    final s = dt.second.toString().padLeft(2, '0');
    return '$h:$m:$s';
  }
}
