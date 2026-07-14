## 1.0.1

**Core Engine Upgrade: Exclusive Handler Guard**
* Added static ownership tracking (`_activeInstance`) to `BarcodeKeyboardService`.
* Guarantees that only **one** hardware keyboard handler is active globally at any time, preventing duplicate scan broadcasts across persistent navigation views.

**Declarative UI Upgrade: `autoPauseOnFocus`**
* Added `autoPauseOnFocus` property (defaulting to `true`) to `BarcodeKeyboardListener`.
* Automatically pauses background hardware scanning whenever an input text field (`EditableText`) gains focus.
* Integrated automatic route visibility checks (`ModalRoute.isCurrent`), ensuring hidden routes never steal scanner ownership.

## 1.0.0

Initial stable release of `barcode_hid_listener`!

**Core Engine**
* **Two-Stage Symbology Gatekeeper:** Built-in validation for global retail and logistics formats (`EAN-13`, `UPC-A`, `EAN-8`, `UPC-E`, `EAN-14`, `Code 39`).
* **Temporal Deduplication:** Built-in shielding to ignore accidental double-scans within configurable time windows.
* **GS1 AI Normalizer:** Automatically intercepts and strips the `01` Application Identifier prefix from 16-digit hardware EAN-14 shipping codes to guarantee 14-digit downstream consistency.

**Architecture & Usage**
* **Declarative Widget Wrapper (`BarcodeKeyboardListener`):** Drop-in UI widget with automatic lifecycle management, dynamic pausing (`enabled`), and `FocusNode` gatekeeping.
* **Imperative Service (`BarcodeKeyboardService`):** Headless Dart streams for advanced state management (Riverpod/Bloc).
* **Proactive Global Focus Shield:** Hardware streams safely pause when active text fields gain focus, preventing OS-level HID wedge duplication.
* **Zero Dependencies:** Pure Dart. Runs flawlessly on iOS, Android, Windows, macOS, Linux, and Web.
