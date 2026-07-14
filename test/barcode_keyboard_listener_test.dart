import 'package:flutter_test/flutter_test.dart';
import 'package:barcode_hid_listener/src/services/barcode_keyboard_service.dart';
import 'package:barcode_hid_listener/src/models/barcode_scanner_config.dart';

void main() {
  test('Exclusive Handler Guard silences previous instance when new instance starts', () {
    TestWidgetsFlutterBinding.ensureInitialized(); // HardwareKeyboard needs bindings
    final serviceA = BarcodeKeyboardService(const BarcodeScannerConfig());
    final serviceB = BarcodeKeyboardService(const BarcodeScannerConfig());

    serviceA.start();
    expect(serviceA.isActive, isTrue);
    expect(serviceB.isActive, isFalse);

    // Starting service B should automatically stop service A
    serviceB.start();
    expect(serviceA.isActive, isFalse);
    expect(serviceB.isActive, isTrue);

    serviceA.dispose();
    serviceB.dispose();
  });
}
