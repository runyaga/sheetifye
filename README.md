<div align="center">

# Sheetifye

### The Native Flutter Spreadsheet Engine — View, Edit, and Persist

[![Pub Version](https://img.shields.io/pub/v/sheetifye?logo=dart&color=0175C2&labelColor=1d1d1f&label=pub&style=for-the-badge)](https://pub.dev/packages/sheetifye)
[![License](https://img.shields.io/badge/license-MIT-22c55e?labelColor=1d1d1f&style=for-the-badge)](LICENSE)
[![Flutter](https://img.shields.io/badge/Flutter-3.10+-54C5F8?logo=flutter&logoColor=white&labelColor=1d1d1f&style=for-the-badge)](https://flutter.dev)
[![Tests](https://img.shields.io/badge/tests-324%20passing-22c55e?labelColor=1d1d1f&style=for-the-badge)](#testing)
[![Issues](https://img.shields.io/github/issues/vikaspoute/sheetifye?labelColor=1d1d1f&color=f59e0b&style=for-the-badge)](https://github.com/vikaspoute/sheetifye/issues)

<br/>

**Sheetifye** is a production-grade Flutter spreadsheet widget with native XLSX & CSV support, a live formula engine, full cell editing, undo/redo, clipboard, autofill, and a complete persistence lifecycle — all rendered directly on the Flutter canvas with no WebView or PlatformView.

<img src="https://raw.githubusercontent.com/vikaspoute/sheetifye/main/screenshots/graphic.png" alt="Sheetifye — Native Flutter Spreadsheet Engine" width="100%" />

<br/>

<table border="0" cellspacing="0" cellpadding="8">
  <tr>
    <td align="center" width="33%">
      <img src="https://raw.githubusercontent.com/vikaspoute/sheetifye/main/screenshots/ios.png" alt="Spreadsheet Editor on iOS" width="100%" />
      <br/><sub><b>📱 iOS</b></sub>
    </td>
    <td align="center" width="33%">
      <img src="https://raw.githubusercontent.com/vikaspoute/sheetifye/main/screenshots/android.png" alt="Excel Viewer on Android" width="100%" />
      <br/><sub><b>🤖 Android</b></sub>
    </td>
    <td align="center" width="33%">
      <img src="https://raw.githubusercontent.com/vikaspoute/sheetifye/main/screenshots/web.png" alt="Flutter Spreadsheet on Web and Desktop" width="100%" />
      <br/><sub><b>🌐 Web / Desktop</b></sub>
    </td>
  </tr>
</table>

[**📖 Docs**](doc/getting_started.md) &nbsp;·&nbsp; [**💡 Example**](example/) &nbsp;·&nbsp; [**📋 Changelog**](CHANGELOG.md) &nbsp;·&nbsp; [**🐛 Issues**](https://github.com/vikaspoute/sheetifye/issues)

</div>

---

## ✨ What's New in v1.1.0

Sheetifye has evolved from a viewer into a **full spreadsheet editing platform**:

- 🖊️ **Cell Editing** — Inline editor overlay with formula support
- 💾 **Persistence Lifecycle** — `onSave`, `onSaveAs`, `onBeforeClose`, `onDiscardChanges` hooks
- ↩️ **Undo / Redo** — Full command stack with dirty-state tracking
- 📋 **Clipboard** — In-app range copy/paste with formula reference shifting + system TSV fallback
- ⚡ **Autofill** — Drag-to-fill with arithmetic and pattern detection
- 🔢 **Live Formula Engine** — AST-based evaluator with real-time dependency recalculation
- 🎛️ **Workbook Actions** — Extensible action menu (bottom sheet on mobile, popup on desktop)
- ✅ **Validation** — Rule-based cell validation with visual feedback
- 🧪 **324 Tests** — Comprehensive coverage across engine, widget, and integration layers

---

## Feature Highlights

| | Feature | Detail |
|:---:|:---|:---|
| ⚡ | **Virtualized Rendering** | 60+ FPS even with millions of cells — direct Canvas painting, no per-cell widgets |
| 📦 | **XLSX & CSV Support** | Native parsers for Excel and CSV files — no WebView, no external services |
| 🖊️ | **Cell Editing** | Inline editor overlay; tap to edit, type `=` for formulas |
| 🔢 | **Formula Engine** | AST tokenizer + evaluator with live dependency graph recalculation |
| ↩️ | **Undo / Redo** | Command-pattern stack; integrates with dirty-state and save lifecycle |
| 📋 | **Clipboard** | Copy/paste ranges with formula shifting; reads system TSV from Excel/Sheets |
| ⚡ | **Autofill** | Drag handle to extend values or arithmetic sequences |
| 💾 | **Persistence Hooks** | Full save lifecycle — dirty tracking, save, save as, discard, close interception |
| 🎛️ | **Workbook Actions** | Extensible menu with built-in and developer-injected actions |
| ✅ | **Validation** | Cell-level rules with blocked input and visual indicators |
| 📐 | **Merged Cells** | Pixel-perfect hit-testing and rendering for complex layouts |
| 🎨 | **Full Theming** | `SheetifyeThemeData` with dark mode auto-detection |
| 🌐 | **Cross-Platform** | iOS, Android, Web, Windows, macOS, Linux |

---

## Supported Platforms

| Platform | Support | Rendering |
|:---|:---:|:---|
| **iOS** | ✅ | Native Canvas |
| **Android** | ✅ | Native Canvas |
| **Web** | ✅ | CanvasKit / HTML |
| **Windows** | ✅ | Native Canvas |
| **macOS** | ✅ | Native Canvas |
| **Linux** | ✅ | Native Canvas |

---

## Installation

```bash
flutter pub add sheetifye
```

Or add to `pubspec.yaml` manually:

```yaml
dependencies:
  sheetifye: ^1.1.0
```

> Sheetifye uses [Riverpod](https://riverpod.dev) for state management. Wrap your app root in a `ProviderScope` once — if you already use Riverpod, no additional setup is needed.

---

## Quick Start

### 1. Initialize

```dart
void main() {
  runApp(const ProviderScope(child: MyApp()));
}
```

### 2. View a Spreadsheet (read-only)

```dart
import 'package:sheetifye/sheetifye.dart';

Sheetifye.asset('assets/reports/sales_2024.xlsx')
```

### 3. Enable Editing + Save Lifecycle

```dart
Sheetifye.asset(
  'assets/reports/sales_2024.xlsx',
  readOnly: false,
  onSave: (workbook) async {
    await myApi.save(WorkbookExporter.toJson(workbook));
    return true; // mark clean
  },
  onSaveAs: (workbook) async {
    final bytes = WorkbookExporter.toXlsxBytes(workbook);
    await FilePicker.saveFile(bytes);
    return true;
  },
  onBeforeClose: () async {
    // Return true to allow close, false to cancel
    return await showSaveDialog(context);
  },
  onWorkbookChanged: (workbook, isDirty) {
    saveIndicator.value = isDirty;
  },
)
```

---

## Usage Examples

### 📁 Load from Asset
```dart
Sheetifye.asset('assets/template.xlsx')
```

### 🌐 Load from Network
```dart
Sheetifye.network(
  'https://api.example.com/reports/latest.xlsx',
  headers: {'Authorization': 'Bearer $token'},
)
```

### 💾 Load from File
```dart
Sheetifye.file(File('/storage/emulated/0/Download/report.xlsx'))
```

### 🧠 Load from Memory (e.g. file picker)
```dart
final result = await FilePicker.platform.pickFiles(withData: true);
Sheetifye.memory(result!.files.first.bytes!)
```

### 📊 Load a CSV File
```dart
Sheetifye.network('https://data.example.com/export.csv')
// CSV is auto-detected by file extension
```

---

## Editing & Formula Entry

When `readOnly: false`, users can:

- **Double-tap** (mobile) or **press Enter / F2** (desktop) to open the inline cell editor
- **Type `=`** to enter formula mode — the formula bar shows the expression, the cell shows the result
- **Tab / Enter** to confirm and advance to the next cell
- **Escape** to cancel

```dart
Sheetifye.asset(
  'assets/data.xlsx',
  readOnly: false, // ← enables the editing system
)
```

---

## Undo & Redo

Every edit is captured in a command stack. Users can undo/redo via:

- **Keyboard shortcuts** — `Ctrl+Z` / `Ctrl+Y` (desktop)
- **Workbook action menu** — Undo and Redo built-in actions

The `onWorkbookChanged` callback fires after each undo/redo, keeping your UI in sync.

---

## Workbook Actions

The workbook action menu provides extensible workbook-level operations. Built-in actions include Save, Save As, Export CSV, Export XLSX, Undo, Redo, and Discard Changes. Add your own:

```dart
import 'package:sheetifye/sheetifye.dart';

Sheetifye.asset(
  'assets/data.xlsx',
  customActions: [
    WorkbookAction(
      id: 'app.share',
      label: 'Share with Team',
      icon: Icons.share,
      group: WorkbookActionGroup.sharing,
      onExecute: (context, ref) async {
        final workbook = ref.read(workbookProvider).workbook;
        final csv = WorkbookExporter.toCsv(workbook);
        await Share.share(csv);
      },
    ),
  ],
)
```

The menu renders as a **bottom sheet on mobile** and a **popup menu on desktop/web** automatically.

---

## Persistence & Export

### Dirty State

```dart
onWorkbookChanged: (workbook, isDirty) {
  // isDirty == true when there are unsaved changes
  setState(() => _hasUnsavedChanges = isDirty);
},
```

### Export Formats

```dart
// JSON (for custom backends)
final json = WorkbookExporter.toJson(workbook);

// CSV (active sheet)
final csv = WorkbookExporter.toCsv(workbook);

// XLSX bytes (for file saving)
final bytes = WorkbookExporter.toXlsxBytes(workbook);
```

---

## Custom Theming

```dart
Sheetifye.asset(
  'assets/data.xlsx',
  theme: SheetifyeThemeData.light().copyWith(
    primaryColor: Colors.deepPurple,
    headerBackground: Colors.grey[50],
    gridColor: Colors.blueGrey[100],
    fontFamily: 'Inter',
  ),
)
```

Dark mode is detected automatically from `Theme.of(context).brightness` when no `theme` is provided.

---

## Architecture

Sheetifye follows a **layered engine architecture** with direct Canvas rendering at its core.

```
lib/src/
├── domain/     Pure entities — Workbook, Sheet, Cell, CellRange
├── data/       Adapters — XLSX parser (isolate), CSV parser, serializer
├── engine/     Runtime systems — Formula, Clipboard, Autofill, Overlays, Structure
├── features/   Riverpod state + UI — Workbook, Grid, Toolbar, Formula Bar, Actions
├── core/       Theme, utilities, grid layout math
└── public/     Consumer-facing API — Sheetifye widget, WorkbookExporter, PersistenceOptions
```

Key design decisions:

- **Canvas-first** — The grid draws directly to `Canvas`, bypassing the Flutter widget tree per cell for maximum throughput.
- **Isolate parsing** — XLSX and CSV files are parsed in a `compute()` isolate, keeping the UI thread free.
- **Command pattern** — Every mutation is encapsulated in a command, enabling undo/redo and dirty-state tracking.
- **Dependency graph** — The formula engine tracks cell relationships for surgical re-evaluation on edit.

→ Full details in [Architecture Guide](doc/architecture.md)

---

## Comparison

| Feature | Sheetifye | Syncfusion | PlutoGrid |
|:---|:---:|:---:|:---:|
| **XLSX Parsing** | ✅ Native | 🟡 Add-on required | ❌ None |
| **CSV Support** | ✅ RFC-4180 | 🟡 Basic | ❌ None |
| **Cell Editing** | ✅ Full | ✅ Full | ✅ Full |
| **Formula Engine** | ✅ AST Native | 🟡 Partial | ❌ None |
| **Undo / Redo** | ✅ Command stack | 🟡 Limited | ❌ None |
| **Clipboard** | ✅ In-app + System | 🟡 Basic | ❌ None |
| **Autofill** | ✅ Smart fill | ❌ None | ❌ None |
| **Virtualization** | ✅ Full | ✅ Full | 🟡 Partial |
| **Memory Usage** | 💎 ~42 MB | 🔴 ~180 MB | 🟡 ~120 MB |
| **License** | MIT | 💰 Commercial | MIT |

---

## Testing

Sheetifye ships with **324 passing tests** across 31+ test files:

| Category | Files | Coverage |
|:---|:---:|:---|
| **Engine — Persistence** | 12 | Dirty state, save lifecycle, crash resistance, recovery, export, async save |
| **Engine — Formula** | 2 | Tokenizer, evaluator, dependency resolution |
| **Engine — Clipboard** | 1 | In-app range copy/paste, TSV parsing, formula shifting |
| **Engine — Editing** | 1 | Cell mutations, validation, undo/redo interaction |
| **Engine — Undo/Redo** | 1 | Command stack, dirty state after undo |
| **Engine — Sorting/Filtering** | 2 | Multi-column sort, filter state |
| **Engine — Autofill** | 1 | Pattern detection, arithmetic sequences |
| **Engine — Virtualization** | 1 | Viewport calculation, scroll accuracy |
| **Engine — Merged Cells** | 1 | Layout, selection, hit-testing |
| **Widget Tests** | 5 | Formula bar, grid, toolbar, editor overlay, workbook |
| **Integration Tests** | 5+ | Mobile UX, desktop UX, web, stress, XLSX samples |

Run the full suite:

```bash
fvm flutter test
```

---

## Roadmap

- [x] **v1.0.0** — Native XLSX viewer, virtualized grid, formula bar, merged cells, theming
- [x] **v1.1.0** — Full editing system, persistence lifecycle, undo/redo, clipboard, autofill, formula engine, workbook actions, validation, mobile UX
- [ ] **v1.2.0** — Conditional formatting, charts, cell comments, multi-sheet editing
- [ ] **v2.0.0** — Collaborative editing hooks, advanced styling, named ranges, pivot-table rendering

---

## Contributing

We welcome contributions! Please read the [Contributing Guide](CONTRIBUTING.md) before opening a PR. Key requirements:

- `fvm flutter test` must pass (324+ tests)
- `fvm flutter analyze` must report zero issues
- New features must include tests and updated docs

## License

Sheetifye is released under the **MIT License**. See [LICENSE](LICENSE) for details.

---

<div align="center">

Built with ❤️ by [Vikas Poute](https://github.com/vikaspoute)

⭐ **If Sheetifye saves you time, please give it a star on [GitHub](https://github.com/vikaspoute/sheetifye).** ⭐

</div>