# Changelog

All notable changes to **Sheetifye** are documented here.
This project follows [Semantic Versioning](https://semver.org/) and [Keep a Changelog](https://keepachangelog.com/en/1.0.0/).

---

## [1.1.0] — 2026-05-18 🚀

This release transforms Sheetifye from a viewer into a **full spreadsheet editing platform**. Every major subsystem has been upgraded or built from scratch, with 324 tests covering the complete lifecycle.

### ✨ Added

#### Editing System
- **Inline Cell Editor** — Double-tap or keyboard entry opens a native text overlay directly over the active cell.
- **Formula Entry** — Type `=` to begin a formula; the formula bar shows the raw expression while the cell renders the computed result.
- **`readOnly` Flag** — Toggle the widget between view-only and fully editable modes at runtime.

#### Persistence Lifecycle
- **`onSave` callback** — Async hook invoked when the user triggers Save; return `true` to mark the workbook clean.
- **`onSaveAs` callback** — Async hook for Save As workflows.
- **`onBeforeClose` callback** — Intercepts back-navigation and window-close events; prompt users to save before exiting.
- **`onDiscardChanges` callback** — Hook for discard/revert flows.
- **`onWorkbookChanged` callback** — Fires whenever the workbook content or dirty state changes; ideal for driving save-indicator UI.
- **`PersistenceOptions`** — Internal provider that decouples lifecycle callbacks from the widget tree.
- **Dirty State Tracking** — `WorkbookState.hasUnsavedChanges` reflects whether there are uncommitted edits.

#### Undo / Redo
- Full undo/redo stack powered by a command pattern architecture.
- Undo/redo interactions correctly update the dirty state flag.
- Accessible via keyboard shortcuts (desktop) and the workbook action menu.

#### Clipboard System
- **In-App Copy/Paste** — Copies a cell range to an internal clipboard with formula reference shifting.
- **System Clipboard** — Falls back to RFC-4180 TSV parsing when pasting from external sources (Excel, Sheets).
- **Formula Shifting** — Relative formula references are automatically adjusted on paste.

#### Autofill Engine
- Drag the autofill handle to extend a cell's value or pattern to adjacent cells.
- Smart-fill detects arithmetic sequences and repeating text patterns.

#### Formula Engine Improvements
- AST-based tokenizer and evaluator for nested formula expressions.
- Live re-evaluation — changing a cell immediately recalculates all dependents.
- Dependency graph tracks cell relationships for targeted invalidation.

#### Workbook Action System
- **`WorkbookAction` model** — Describes any executable workbook-level action (id, label, icon, group, callbacks).
- **`WorkbookActionGroup` enum** — `file`, `sharing`, `workbook`, `view`, `developer`, `other`.
- **`customActions` parameter** — Inject developer-defined actions into the workbook menu from the host app.
- **Adaptive menu** — Renders as a bottom sheet on mobile and a popup menu on desktop/web.
- **Built-in actions** — Save, Save As, Export CSV, Export XLSX, Undo, Redo, Discard Changes.

#### Export API
- `WorkbookExporter.toCsv(workbook)` — Export any sheet to a CSV string.
- `WorkbookExporter.toXlsxBytes(workbook)` — Export the active sheet to a minimal XLSX byte array.
- `WorkbookExporter.toJson(workbook)` — Serialize the full workbook to JSON.

#### Overlay System
- Cell editor overlay renders above the grid canvas without disrupting scroll state.
- Autofill drag-handle overlay with gesture detection.
- `OverlayManager` coordinates all overlay layers cleanly.

#### Validation
- Cell validation rules enforceable at the engine level.
- Invalid entries are highlighted and blocked based on configured constraints.

#### Mobile UX
- Adaptive toolbar for touch devices: contextual bottom sheet replaces the desktop popup menu.
- Touch-optimized selection handles.
- Soft keyboard interaction managed transparently by the editor overlay.

### 🚀 Improved

- **CSV Support** — CSV parsing upgraded to RFC-4180 compliant scanner supporting quoted fields, escaped commas, and CRLF line endings.
- **Sorting** — Sort any column ascending/descending while maintaining row index integrity via `rowIndexManager`.
- **Filtering** — Column filters now track active state and can be cleared independently.
- **Merged Cell Hit Testing** — Accurate selection and editing within merged regions.
- **Shimmer Loading** — Refined shimmer animation during initial file parsing.
- **Error Widget** — Default error UI now shows a Retry button when file loading fails.
- **Source `cacheKey`** — Widget correctly reloads when the source changes without requiring a full rebuild.

### 🔧 Fixed

- Fixed `use_build_context_synchronously` — `ScaffoldMessenger` captured before `await` gaps in example app.
- Fixed `implementation_imports` — `WorkbookAction` is now exported from the public library barrel.
- Fixed `curly_braces_in_flow_control_structures` — All bare `if` statements in the clipboard manager now use blocks.
- Fixed merged cell scroll rendering artifacts on high-DPI displays.
- Fixed formula bar not updating when navigating between sheets.

### ⚡ Performance

- Background parsing via `compute()` isolates XLSX and CSV parsing from the UI thread.
- LRU cache bounds memory usage regardless of dataset size.
- Formula dependency graph ensures only affected cells re-evaluate on mutation.
- Undo/redo stack operations complete in <1 ms.

### 🧪 Testing

- **324 tests** across 31+ test files — all passing.
- **17 engine test categories**: clipboard, CSV, editing, filtering, formulas, interoperability, merged cells, overlays, persistence (12 files), recalculation, scrolling, selection, sorting, structure, undo/redo, validation, virtualization.
- **5 widget test categories**: editor overlay, formula bar, grid, toolbar, workbook.
- **5 integration test categories**: desktop, mobile, web, stress, XLSX samples.

### ⚠️ Breaking Changes

None. All new parameters (`onSave`, `onSaveAs`, `onBeforeClose`, `onDiscardChanges`, `onWorkbookChanged`, `customActions`) are optional and default to the original read-only viewer behavior. Existing integrations require no migration.

---

## [1.0.2] — 2026-05-13

### 🚀 Improved
- **SEO & Discoverability** — Optimized all documentation for search engines and pub.dev rankings.
- **Onboarding Experience** — Restructured README with clear installation and usage guides.
- **Example Gallery** — Polished the example application and simplified the quick-start guide.

---

## [1.0.1] — 2026-05-12

### 🔧 Fixed
- Fixed minor rendering artifacts in merged cell regions on specific screen densities.
- Improved memory cleanup when disposing of large workbooks.

---

## [1.0.0] — 2026-05-12 🎉

### ✨ Added
- **Virtualized Rendering Engine** — High-performance grid maintaining 60+ FPS on workbooks of any size.
- **Native XLSX Parsing** — Full in-app Excel reader supporting `assets`, `file`, `memory`, and `network` sources.
- **Bi-directional Scrolling** — Smooth horizontal and vertical navigation.
- **Selection System** — Advanced single-cell and range selection with keyboard and touch support.
- **Formula Bar** — Professional UI for viewing raw cell values and computed results.
- **Merged Cell Support** — Accurate rendering and hit-testing for complex spreadsheet layouts.
- **Custom Theming** — Theme-aware UI that integrates seamlessly with your app's brand.

---

<sub>Built with ❤️ for the Flutter community. <a href="https://github.com/vikaspoute/sheetifye/issues">Report an issue</a> or <a href="https://github.com/vikaspoute/sheetifye/releases">view releases</a>.</sub>