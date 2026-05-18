# Contributing to Sheetifye

Thank you for considering a contribution to **Sheetifye** — a production-grade Flutter spreadsheet engine. We welcome bug reports, feature proposals, documentation improvements, and pull requests of all sizes.

---

## 🛠️ How Can I Contribute?

### 🐛 Reporting Bugs
- **Search first** — Check existing [issues](https://github.com/vikaspoute/sheetifye/issues) before opening a new one.
- **Be descriptive** — Include your Flutter version (`flutter doctor`), device info, and clear steps to reproduce.
- **Provide context** — Screenshots, GIFs, or a minimal reproduction project are invaluable.

### ✨ Feature Requests
- Open a [Discussion](https://github.com/vikaspoute/sheetifye/discussions) first for large proposals.
- Explain the use case — why does this improve the developer or end-user experience?
- If relevant, sketch the public API you'd like to see.

### ⌨️ Pull Requests

1. **Fork & branch** — Create your feature branch from `main`.
2. **Follow style** — Adhere to [Effective Dart](https://dart.dev/guides/language/effective-dart) guidelines.
3. **Write tests** — New features must include unit tests. Bug fixes should include a regression test.
4. **Keep the bar green** — Run `fvm flutter test` and ensure all 324+ tests pass.
5. **Zero warnings** — Run `fvm flutter analyze` and resolve every issue before opening a PR.
6. **Update docs** — If you change a public API, update the relevant files in `doc/` and the main `README.md`.

---

## 🏗️ Technical Guidelines

Sheetifye is built on a layered engine architecture. Before contributing to the core, please read:

- [Architecture Guide](doc/architecture.md) — engine subsystems, rendering pipeline, state management
- [Persistence Guide](doc/persistence.md) — save lifecycle, dirty state, export API
- [Workbook Actions Guide](doc/workbook_actions.md) — extending the action menu
- [Performance Benchmarks](doc/benchmarks/benchmark_report.md) — performance targets we protect

### Key Principles

| Principle | Detail |
|:---|:---|
| **Canvas-First Rendering** | The grid must paint directly to the `Canvas`. No per-cell widgets. |
| **Isolate-Safe Parsing** | Heavy XLSX/CSV parsing runs in a `compute()` isolate, never on the UI thread. |
| **Command Pattern Mutations** | All cell edits go through the command stack to preserve undo/redo correctness. |
| **Lightweight Dependencies** | We keep the dependency surface minimal. Propose alternatives before adding packages. |
| **Adaptive UX** | UI components must behave correctly on mobile (touch) and desktop (mouse/keyboard). |

### Extension Points

You can extend Sheetifye without modifying the core engine:

- **`customActions`** — Inject `WorkbookAction` instances from the host app to add menu items.
- **`loadingBuilder`** — Replace the default shimmer with a custom loading widget.
- **`errorBuilder`** — Provide a branded error state.
- **`SheetifyeThemeData`** — Customize every visual token.

---

## 🧪 Testing Philosophy

Sheetifye maintains **324 tests** across three categories:

| Category | Scope |
|:---|:---|
| **Engine tests** | Clipboard, formulas, persistence lifecycle, undo/redo, autofill, sorting, filtering, validation, virtualization |
| **Widget tests** | Formula bar, grid, toolbar, editor overlay, workbook widget |
| **Integration tests** | Mobile UX, desktop UX, web UX, stress tests, XLSX interoperability |

Every PR must maintain or improve this coverage.

---

## 📜 Code of Conduct

Be respectful and constructive in all interactions. We follow the [Contributor Covenant](CODE_OF_CONDUCT.md).

## Questions?

Open a [Discussion](https://github.com/vikaspoute/sheetifye/discussions) or reach out to the maintainers via GitHub.

---

<sub>Thank you for helping us build the best Flutter spreadsheet engine!</sub>
