import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sheetifye/sheetifye.dart';
import 'package:sheetifye/src/engine/formula/recalculation_engine.dart';
import 'package:sheetifye/src/engine/commands/command_manager.dart';
import 'package:sheetifye/src/engine/commands/cell_commands.dart';
import 'package:sheetifye/src/engine/clipboard/clipboard_manager.dart';
import 'package:sheetifye/src/engine/layout/layout_engine.dart';
import 'package:sheetifye/src/data/adapters/xlsx/xlsx_adapter.dart';
import 'package:sheetifye/src/engine/validation/validation_engine.dart';
import 'package:sheetifye/src/engine/autofill/autofill_engine.dart';
import 'dart:typed_data';
import 'dart:collection';

class WorkbookState {
  final Workbook workbook;
  final GridCoordinate? activeCell;
  final GridRange? mainSelection;
  final List<GridRange> additionalSelections;
  final bool isDragging;
  final bool isEditing;
  final String? editValue;
  final String? validationError;
  final bool readOnly;
  final String? searchQuery;
  final bool isSearchOpen;
  final bool canUndo;
  final bool canRedo;
  final int cleanRevision;
  final GridRange? pendingCutRange;
  final String? pendingCutSheetId;
  final bool hasPendingCutBeenPasted;

  WorkbookState({
    required this.workbook,
    this.activeCell,
    this.mainSelection,
    this.additionalSelections = const [],
    this.isDragging = false,
    this.isEditing = false,
    this.editValue,
    this.validationError,
    this.readOnly = true,
    this.searchQuery,
    this.isSearchOpen = false,
    this.canUndo = false,
    this.canRedo = false,
    this.cleanRevision = 0,
    this.pendingCutRange,
    this.pendingCutSheetId,
    this.hasPendingCutBeenPasted = false,
  });

  bool get hasUnsavedChanges => workbook.revision != cleanRevision;

  WorkbookState copyWith({
    Workbook? workbook,
    dynamic activeCell = const Object(),
    dynamic mainSelection = const Object(),
    List<GridRange>? additionalSelections,
    bool? isDragging,
    bool? isEditing,
    dynamic editValue = const Object(),
    dynamic validationError = const Object(),
    bool? readOnly,
    dynamic searchQuery = const Object(),
    bool? isSearchOpen,
    bool? canUndo,
    bool? canRedo,
    int? cleanRevision,
    dynamic pendingCutRange = const Object(),
    dynamic pendingCutSheetId = const Object(),
    bool? hasPendingCutBeenPasted,
  }) {
    const sentinel = Object();
    return WorkbookState(
      workbook: workbook ?? this.workbook,
      activeCell: identical(activeCell, sentinel)
          ? this.activeCell
          : (activeCell as GridCoordinate?),
      mainSelection: identical(mainSelection, sentinel)
          ? this.mainSelection
          : (mainSelection as GridRange?),
      additionalSelections: additionalSelections ?? this.additionalSelections,
      isDragging: isDragging ?? this.isDragging,
      isEditing: isEditing ?? this.isEditing,
      editValue: identical(editValue, sentinel)
          ? this.editValue
          : (editValue as String?),
      validationError: identical(validationError, sentinel)
          ? this.validationError
          : (validationError as String?),
      readOnly: readOnly ?? this.readOnly,
      searchQuery: identical(searchQuery, sentinel)
          ? this.searchQuery
          : (searchQuery as String?),
      isSearchOpen: isSearchOpen ?? this.isSearchOpen,
      canUndo: canUndo ?? this.canUndo,
      canRedo: canRedo ?? this.canRedo,
      cleanRevision: cleanRevision ?? this.cleanRevision,
      pendingCutRange: identical(pendingCutRange, sentinel)
          ? this.pendingCutRange
          : (pendingCutRange as GridRange?),
      pendingCutSheetId: identical(pendingCutSheetId, sentinel)
          ? this.pendingCutSheetId
          : (pendingCutSheetId as String?),
      hasPendingCutBeenPasted:
          hasPendingCutBeenPasted ?? this.hasPendingCutBeenPasted,
    );
  }
}

class WorkbookController extends StateNotifier<WorkbookState> {
  final CommandManager _commandManager = CommandManager();
  final ClipboardManager _clipboardManager = ClipboardManager();
  final RecalculationEngine _recalculationEngine = RecalculationEngine();
  final ValidationEngine _validationEngine = ValidationEngine();

  final ListQueue<Workbook> _undoWorkbookStack = ListQueue();
  final ListQueue<Workbook> _redoWorkbookStack = ListQueue();

  void _saveSnapshot() {
    final sheetsCopy = state.workbook.sheets.map((s) {
      return s.copyWith(cells: Map<String, Cell>.from(s.cells));
    }).toList();
    final workbookCopy = state.workbook.copyWith(sheets: sheetsCopy);
    _undoWorkbookStack.addLast(workbookCopy);
    _redoWorkbookStack.clear();
    if (_undoWorkbookStack.length > 100) {
      _undoWorkbookStack.removeFirst();
    }
  }

  WorkbookController()
    : super(
        WorkbookState(
          workbook: Workbook(
            id: 'default-workbook',
            name: 'New Workbook',
            sheets: [Sheet(id: 'sheet-1', name: 'Sheet1')],
          ),
        ),
      ) {
    // Add a default numeric validation rule to B1 (0, 1) for demonstration
    _validationEngine.setValidation(
      0,
      1,
      ValidationRule(
        type: ValidationType.number,
        criteria: null,
        errorMessage: 'Cell B1 only accepts numeric values!',
        allowEmpty: true,
      ),
    );
  }

  @override
  set state(WorkbookState value) {
    super.state = value.copyWith(
      canUndo: _undoWorkbookStack.isNotEmpty,
      canRedo: _redoWorkbookStack.isNotEmpty,
    );
  }

  bool get canEdit => !state.readOnly;

  void selectAll() {
    final sheet = state.workbook.activeSheet;
    int maxRow = 0;
    int maxCol = 0;
    for (final key in sheet.cells.keys) {
      final parts = key.split(',');
      if (parts.length == 2) {
        final r = int.tryParse(parts[0]) ?? 0;
        final c = int.tryParse(parts[1]) ?? 0;
        if (r > maxRow) maxRow = r;
        if (c > maxCol) maxCol = c;
      }
    }
    if (maxRow < 9) maxRow = 9;
    if (maxCol < 9) maxCol = 9;

    state = state.copyWith(
      activeCell: const GridCoordinate(0, 0),
      mainSelection: GridRange.fromRect(0, 0, maxRow, maxCol),
      additionalSelections: [],
      isEditing: false,
      editValue: null,
      validationError: null,
    );
  }

  void setReadOnly(bool readOnly) {
    state = state.copyWith(
      readOnly: readOnly,
      isEditing: false,
      editValue: null,
      validationError: null,
    );
  }

  void loadWorkbook(Workbook workbook) {
    state = state.copyWith(
      workbook: workbook,
      readOnly: false,
      editValue: null,
      validationError: null,
    );

    // Initial recalculation for all formulas
    for (final entry in workbook.activeSheet.cells.entries) {
      if (entry.value.formula != null) {
        _recalculateCell(entry.key, entry.value.formula!);
      }
    }

    // Select the first cell by default
    selectCell(0, 0);
    _notifyState(isDirtyChange: false);
    markAsClean();
  }

  void loadFromXlsx(Uint8List bytes) {
    final workbook = XlsxAdapter.parse(bytes);
    loadWorkbook(workbook);
  }

  void switchSheet(int index) {
    final workbook = state.workbook.copyWith(activeSheetIndex: index);
    state = state.copyWith(
      workbook: workbook,
      editValue: null,
      validationError: null,
    );

    // Recalculate all formulas in the new sheet
    for (final entry in workbook.activeSheet.cells.entries) {
      if (entry.value.formula != null) {
        _recalculateCell(entry.key, entry.value.formula!);
      }
    }
    _notifyState(isDirtyChange: false);
  }

  void addSheet() {
    if (!canEdit) return;
    _saveSnapshot();
    final newSheet = Sheet(
      id: 'sheet-${state.workbook.sheets.length + 1}',
      name: 'Sheet${state.workbook.sheets.length + 1}',
    );
    final sheets = List<Sheet>.from(state.workbook.sheets)..add(newSheet);
    final workbook = state.workbook.copyWith(
      sheets: sheets,
      activeSheetIndex: sheets.length - 1,
    );
    state = state.copyWith(workbook: workbook);
    _notifyState();
  }

  void deleteSheet(int index) {
    if (!canEdit) return;
    final currentWorkbook = state.workbook;
    if (currentWorkbook.sheets.length <= 1) return;

    _saveSnapshot();
    // Create a fresh list for immutability and notification
    final List<Sheet> newSheets = List<Sheet>.from(currentWorkbook.sheets);
    newSheets.removeAt(index);

    int newActiveIndex = currentWorkbook.activeSheetIndex;

    // Adjust active index if it's now out of bounds
    if (newActiveIndex >= newSheets.length) {
      newActiveIndex = newSheets.length - 1;
    }

    // Force state update with clean references
    final updatedWorkbook = currentWorkbook.copyWith(
      sheets: newSheets,
      activeSheetIndex: newActiveIndex,
    );

    state = state.copyWith(
      workbook: updatedWorkbook,
      activeCell: null,
      mainSelection: null,
      additionalSelections: [],
      isEditing: false,
      editValue: null,
      validationError: null,
      pendingCutRange: null,
      pendingCutSheetId: null,
      hasPendingCutBeenPasted: false,
    );

    _notifyState(isDirtyChange: true);
  }

  void renameSheet(int index, String newName) {
    if (!canEdit) return;
    _saveSnapshot();
    final sheets = List<Sheet>.from(state.workbook.sheets);
    sheets[index] = sheets[index].copyWith(name: newName);
    final workbook = state.workbook.copyWith(sheets: sheets);
    state = state.copyWith(workbook: workbook);
    _notifyState();
  }

  void importCSV(String csvContent, {String? sheetName}) {
    if (!canEdit) return;
    final grid = GridUtils.parseCSV(csvContent);
    if (grid.isEmpty) return;

    final Map<String, Cell> cells = {};
    int maxRow = 0;
    int maxCol = 0;

    for (int r = 0; r < grid.length; r++) {
      final rowData = grid[r];
      if (r > maxRow) maxRow = r;
      for (int c = 0; c < rowData.length; c++) {
        if (c > maxCol) maxCol = c;
        final valStr = rowData[c];
        if (valStr.isEmpty) continue;

        final bool isFormula = valStr.startsWith('=');
        cells['$r,$c'] = Cell(
          id: '$r,$c',
          row: r,
          column: c,
          value: isFormula ? null : valStr,
          rawInput: valStr,
          formula: isFormula ? valStr : null,
        );
      }
    }

    final name = sheetName ?? 'Imported CSV';
    final newSheet = Sheet(
      id: 'csv-${DateTime.now().millisecondsSinceEpoch}',
      name: name,
      cells: cells,
      rowCount: maxRow > 1000 ? maxRow + 100 : 1000,
      columnCount: maxCol > 26 ? maxCol + 10 : 26,
    );

    final sheets = List<Sheet>.from(state.workbook.sheets)..add(newSheet);
    final workbook = state.workbook.copyWith(
      sheets: sheets,
      activeSheetIndex: sheets.length - 1,
    );

    state = state.copyWith(workbook: workbook);

    // Process recalculation for all formulas in imported CSV
    cells.forEach((key, cell) {
      if (cell.formula != null) {
        _recalculateCell(key, cell.formula!);
      }
    });

    _notifyState();
  }

  String exportCSV() {
    final sheet = state.workbook.activeSheet;
    int maxRow = 0;
    int maxCol = 0;
    bool hasCells = false;

    for (final key in sheet.cells.keys) {
      final parts = key.split(',');
      if (parts.length == 2) {
        final r = int.parse(parts[0]);
        final c = int.parse(parts[1]);
        if (r > maxRow) maxRow = r;
        if (c > maxCol) maxCol = c;
        hasCells = true;
      }
    }

    if (!hasCells) return '';

    final buffer = StringBuffer();
    for (int r = 0; r <= maxRow; r++) {
      final rowValues = <String>[];
      for (int c = 0; c <= maxCol; c++) {
        final cell = sheet.cells['$r,$c'];
        final val = cell?.rawInput ?? cell?.value?.toString() ?? '';
        rowValues.add(GridUtils.formatCSVField(val));
      }
      buffer.write(rowValues.join(','));
      if (r < maxRow) {
        buffer.write('\n');
      }
    }
    return buffer.toString();
  }

  void updateCellValue(int row, int col, dynamic value) {
    if (!canEdit) return;
    _saveSnapshot();
    final command = UpdateCellCommand(row: row, col: col, newValue: value);
    _commandManager.execute(command, state.workbook);

    // Trigger recalculation
    _recalculateCell('$row,$col', value.toString());
    _notifyState();
  }

  void _recalculateCell(String address, String input, {Sheet? targetSheet}) {
    final sheetToUse = targetSheet ?? state.workbook.activeSheet;
    _recalculationEngine.processCellUpdate(address, input, sheetToUse, (
      addr,
      computedValue,
    ) {
      final existing = sheetToUse.cells[addr];
      if (existing != null) {
        sheetToUse.cells[addr] = existing.copyWith(value: computedValue);
      }
    });
  }

  void undo() {
    if (!canEdit) return;
    if (_undoWorkbookStack.isNotEmpty) {
      final currentWorkbook = state.workbook;
      final previousWorkbook = _undoWorkbookStack.removeLast();
      _redoWorkbookStack.addLast(currentWorkbook);
      state = state.copyWith(workbook: previousWorkbook);
      _notifyState(isDirtyChange: false);
    }
  }

  void redo() {
    if (!canEdit) return;
    if (_redoWorkbookStack.isNotEmpty) {
      final currentWorkbook = state.workbook;
      final nextWorkbook = _redoWorkbookStack.removeLast();
      _undoWorkbookStack.addLast(currentWorkbook);
      state = state.copyWith(workbook: nextWorkbook);
      _notifyState(isDirtyChange: false);
    }
  }

  Future<void> cut() async {
    if (!canEdit) return;
    if (state.mainSelection != null) {
      await copy();
      state = state.copyWith(
        pendingCutRange: state.mainSelection,
        pendingCutSheetId: state.workbook.activeSheet.id,
        hasPendingCutBeenPasted: false,
      );
      _notifyState(isDirtyChange: false);
    }
  }

  void clearRange(GridRange range) {
    if (!canEdit) return;
    _saveSnapshot();
    final sheet = state.workbook.activeSheet;
    final Map<String, dynamic> clearValues = {};
    for (int r = range.minRow; r <= range.maxRow; r++) {
      final logicalR = sheet.rowIndexManager.getLogicalIndex(r);
      for (int c = range.minCol; c <= range.maxCol; c++) {
        clearValues['$logicalR,$c'] = null;
      }
    }
    final command = UpdateRangeCommand(clearValues);
    _commandManager.execute(command, state.workbook);
    _notifyState();
  }

  Future<void> copy() async {
    if (state.mainSelection != null) {
      await _clipboardManager.copyToClipboard(
        state.mainSelection!,
        state.workbook.activeSheet,
      );
      if (state.pendingCutRange != null) {
        state = state.copyWith(
          pendingCutRange: null,
          pendingCutSheetId: null,
          hasPendingCutBeenPasted: false,
        );
      }
    }
  }

  Future<void> paste() async {
    if (!canEdit) return;
    if (state.activeCell != null) {
      final sheet = state.workbook.activeSheet;
      final mutations = await _clipboardManager.getFromClipboard(
        state.activeCell!,
        sheet,
      );

      if (mutations != null) {
        // 1. Merged cell boundaries safety check
        bool hasMergeOverlap = false;
        for (final addr in mutations.keys) {
          final parts = addr.split(',');
          if (parts.length == 2) {
            final r = int.parse(parts[0]);
            final c = int.parse(parts[1]);
            final region = sheet.mergedCells.getRegionFor(r, c);
            if (region != null) {
              // It's part of a merged region. If it is NOT the top-left cell, it is an invalid overlap paste!
              if (!region.isTopLeft(r, c)) {
                hasMergeOverlap = true;
                break;
              }
            }
          }
        }

        if (hasMergeOverlap) {
          state = state.copyWith(
            validationError: "Cannot paste: Target overlaps with merged cells!",
          );
          _notifyState();
          return;
        }

        // 2. Cell Validation grace rules
        final Map<String, dynamic> validatedMutations = {};
        String? lastValidationError;

        mutations.forEach((addr, val) {
          final parts = addr.split(',');
          if (parts.length == 2) {
            final r = int.parse(parts[0]);
            final c = int.parse(parts[1]);
            final stringVal = val?.toString() ?? '';

            if (_validationEngine.isValid(r, c, stringVal)) {
              validatedMutations[addr] = val;
            } else {
              final rule = _validationEngine.getRule(r, c);
              lastValidationError =
                  rule?.errorMessage ??
                  'Value violates validation rule at cell ${GridUtils.getAddress(r, c)}!';
            }
          }
        });

        // 3. Batch commit & recalculation
        if (validatedMutations.isNotEmpty) {
          _saveSnapshot();

          Sheet? cutSheet;
          List<String> crossSheetClears = [];

          if (state.pendingCutRange != null &&
              state.pendingCutSheetId != null &&
              !state.hasPendingCutBeenPasted) {
            final cutSheetId = state.pendingCutSheetId!;
            final activeSheetId = state.workbook.activeSheet.id;

            if (cutSheetId == activeSheetId) {
              // Same sheet: merge clears into validatedMutations so UpdateRangeCommand processes them together,
              // avoiding overwriting paste cells if they overlap.
              final cutRange = state.pendingCutRange!;
              for (int r = cutRange.minRow; r <= cutRange.maxRow; r++) {
                final logicalR = sheet.rowIndexManager.getLogicalIndex(r);
                for (int c = cutRange.minCol; c <= cutRange.maxCol; c++) {
                  final key = '$logicalR,$c';
                  if (!validatedMutations.containsKey(key)) {
                    validatedMutations[key] = null;
                  }
                }
              }
            } else {
              // Different sheet: safely remove the cells directly from the source sheet
              try {
                cutSheet = state.workbook.sheets.firstWhere(
                  (s) => s.id == cutSheetId,
                );
                for (
                  int r = state.pendingCutRange!.minRow;
                  r <= state.pendingCutRange!.maxRow;
                  r++
                ) {
                  final logicalR = cutSheet.rowIndexManager.getLogicalIndex(r);
                  for (
                    int c = state.pendingCutRange!.minCol;
                    c <= state.pendingCutRange!.maxCol;
                    c++
                  ) {
                    final key = '$logicalR,$c';
                    cutSheet.cells.remove(key);
                    crossSheetClears.add(key);
                  }
                }
              } catch (e) {
                // Sheet might have been deleted, ignore
              }
            }

            state = state.copyWith(hasPendingCutBeenPasted: true);
          }

          final command = UpdateRangeCommand(validatedMutations);
          _commandManager.execute(command, state.workbook);

          validatedMutations.forEach((addr, val) {
            final String valStr = val?.toString() ?? '';
            _recalculateCell(addr, valStr);
          });

          if (cutSheet != null) {
            for (final addr in crossSheetClears) {
              _recalculateCell(addr, '', targetSheet: cutSheet);
            }
          }
        }

        state = state.copyWith(validationError: lastValidationError);
        _notifyState();
      }
    }
  }

  void sortRange(GridRange range, int column, {bool ascending = true}) {
    final sheet = state.workbook.activeSheet;
    final List<Map<int, Cell>> rowsToSort = [];

    // Collect data
    for (int r = range.minRow; r <= range.maxRow; r++) {
      final Map<int, Cell> rowData = {};
      for (int c = range.minCol; c <= range.maxCol; c++) {
        final cell =
            sheet.cells['$r,$c'] ??
            Cell(id: '$r,$c', row: r, column: c, value: null);
        rowData[c] = cell;
      }
      rowsToSort.add(rowData);
    }

    // Sort
    rowsToSort.sort((a, b) {
      final valA = a[column]?.value;
      final valB = b[column]?.value;
      if (valA == null && valB == null) return 0;
      if (valA == null) return 1;
      if (valB == null) return -1;

      if (valA is Comparable && valB is Comparable) {
        final cmp = valA.compareTo(valB);
        return ascending ? cmp : -cmp;
      }
      return 0;
    });

    // Apply
    if (!canEdit) return;
    final Map<String, dynamic> newValues = {};
    for (int i = 0; i < rowsToSort.length; i++) {
      final targetRow = range.minRow + i;
      rowsToSort[i].forEach((col, cell) {
        newValues['$targetRow,$col'] = cell.value;
      });
    }

    _saveSnapshot();
    final command = UpdateRangeCommand(newValues);
    _commandManager.execute(command, state.workbook);
    _notifyState();
  }

  void _notifyState({bool isDirtyChange = true}) {
    if (isDirtyChange) {
      final newWorkbook = state.workbook.copyWith(
        revision: state.workbook.revision + 1,
      );
      state = state.copyWith(workbook: newWorkbook);
    } else {
      state = state.copyWith(workbook: state.workbook);
    }
  }

  void markAsClean() {
    state = state.copyWith(cleanRevision: state.workbook.revision);
  }

  void selectCell(int row, int col) {
    expandIfNeeded(row, col);
    final range = GridRange.fromRect(row, col, row, col);
    state = state.copyWith(
      activeCell: GridCoordinate(row, col),
      mainSelection: range,
      additionalSelections: [],
      isEditing: false,
      editValue: null,
      validationError: null,
    );
  }

  void expandIfNeeded(int row, int col) {
    if (!canEdit) return;
    final sheet = state.workbook.activeSheet;
    bool needsUpdate = false;
    int newRowCount = sheet.rowCount;
    int newColCount = sheet.columnCount;

    // Expand rows if near or beyond boundary
    if (row >= sheet.rowCount - 5) {
      newRowCount = row + 100;
      needsUpdate = true;
    }

    // Expand columns if near or beyond boundary
    if (col >= sheet.columnCount - 2) {
      newColCount = col + 10;
      needsUpdate = true;
    }

    if (needsUpdate) {
      _saveSnapshot();
      final newSheet = sheet.copyWith(
        rowCount: newRowCount,
        columnCount: newColCount,
        rowIndexManager: sheet.rowIndexManager.copyWith(newRowCount),
      );
      final sheets = List<Sheet>.from(state.workbook.sheets);
      sheets[state.workbook.activeSheetIndex] = newSheet;

      state = state.copyWith(workbook: state.workbook.copyWith(sheets: sheets));
    }
  }

  void expandSelection(int rowOffset, int colOffset) {
    if (state.activeCell != null && state.mainSelection != null) {
      final currentEnd = state.mainSelection!.end;
      final newEndRow = (currentEnd.row + rowOffset).clamp(0, 2000000);
      final newEndCol = (currentEnd.column + colOffset).clamp(0, 16384);
      expandIfNeeded(newEndRow, newEndCol);
      state = state.copyWith(
        mainSelection: GridRange(
          start: state.activeCell!,
          end: GridCoordinate(newEndRow, newEndCol),
        ),
      );
    }
  }

  void startDrag(int row, int col) {
    expandIfNeeded(row, col);
    final coord = GridCoordinate(row, col);
    state = state.copyWith(
      activeCell: coord,
      mainSelection: GridRange.fromRect(row, col, row, col),
      isDragging: true,
      additionalSelections: [],
      isEditing: false,
      editValue: null,
      validationError: null,
    );
  }

  void updateDrag(int row, int col) {
    if (state.isDragging && state.activeCell != null) {
      expandIfNeeded(row, col);
      final newRange = GridRange(
        start: state.activeCell!,
        end: GridCoordinate(row, col),
      );
      state = state.copyWith(mainSelection: newRange);
    }
  }

  void endDrag() {
    state = state.copyWith(isDragging: false);
  }

  void setEditing(bool editing, {String? initialValue}) {
    if (!canEdit && editing) return;

    String? val;
    if (editing) {
      if (initialValue != null) {
        val = initialValue;
      } else if (state.activeCell != null) {
        final cell = state
            .workbook
            .activeSheet
            .cells['${state.activeCell!.row},${state.activeCell!.column}'];
        val = cell?.rawInput ?? cell?.value?.toString() ?? '';
      } else {
        val = '';
      }
    }

    state = state.copyWith(
      isEditing: editing,
      editValue: val,
      validationError: null,
    );
  }

  void updateEditValue(String value) {
    if (!state.isEditing) return;
    state = state.copyWith(editValue: value);
  }

  void commitEdit(String value) {
    if (!canEdit) {
      state = state.copyWith(
        isEditing: false,
        editValue: null,
        validationError: null,
      );
      return;
    }
    if (state.activeCell != null) {
      final row = state.activeCell!.row;
      final col = state.activeCell!.column;

      // Run validation check
      final isValid = _validationEngine.isValid(row, col, value);
      if (!isValid) {
        final rule = _validationEngine.getRule(row, col);
        state = state.copyWith(
          validationError: rule?.errorMessage ?? 'Invalid cell value!',
        );
        return; // Prevents committing, keeps editing overlay active for correction
      }

      updateCellValue(row, col, value);
    }
    state = state.copyWith(
      isEditing: false,
      editValue: null,
      validationError: null,
    );
  }

  void cancelEdit() {
    state = state.copyWith(
      isEditing: false,
      editValue: null,
      validationError: null,
    );
  }

  void dismissValidationError() {
    state = state.copyWith(validationError: null);
  }

  void autofill(GridRange source, GridRange target) {
    if (!canEdit) return;
    final autofillEngine = AutofillEngine();
    final sheet = state.workbook.activeSheet;
    final mutations = autofillEngine.generateFill(source, target, sheet);

    if (mutations.isNotEmpty) {
      _saveSnapshot();
      final command = UpdateRangeCommand(mutations);
      _commandManager.execute(command, state.workbook);

      // Recalculate all affected cells
      mutations.forEach((addr, val) {
        _recalculateCell(addr, val.toString());
      });

      _notifyState();
    }
  }

  void toggleSearch() {
    state = state.copyWith(isSearchOpen: !state.isSearchOpen);
    if (!state.isSearchOpen) {
      state = state.copyWith(searchQuery: null);
    }
  }

  void updateSearch(String query) {
    state = state.copyWith(searchQuery: query);
  }

  void moveActiveCell(int rowOffset, int colOffset) {
    if (state.isEditing) return;
    if (state.activeCell != null) {
      final newRow = (state.activeCell!.row + rowOffset).clamp(0, 2000000);
      final newCol = (state.activeCell!.column + colOffset).clamp(0, 16384);
      selectCell(newRow, newCol);
    }
  }
}

final workbookProvider =
    StateNotifierProvider<WorkbookController, WorkbookState>((ref) {
      return WorkbookController();
    });

final layoutProvider = Provider<LayoutEngine>((ref) {
  return LayoutEngine();
});

int min(int a, int b) => a < b ? a : b;
int max(int a, int b) => a > b ? a : b;
