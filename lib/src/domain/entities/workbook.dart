import 'package:flutter/material.dart';
import 'package:sheetifye/src/engine/merge/merged_cell_manager.dart';
import 'package:sheetifye/src/engine/sort/index_mapping_engine.dart';
import 'package:sheetifye/src/domain/entities/cell.dart';

@immutable
class Sheet {
  final String id;
  final String name;
  final Map<String, Cell> cells;
  final List<double> columnWidths;
  final List<double> rowHeights;
  final int rowCount;
  final int columnCount;
  final int frozenRows;
  final int frozenColumns;
  final MergedCellManager mergedCells;
  final IndexMappingEngine rowIndexManager;
  final VisibilityManager visibilityManager;

  Sheet({
    required this.id,
    required this.name,
    Map<String, Cell>? cells,
    this.columnWidths = const [],
    this.rowHeights = const [],
    this.rowCount = 1000,
    this.columnCount = 26,
    this.frozenRows = 0,
    this.frozenColumns = 0,
    MergedCellManager? mergedCells,
    IndexMappingEngine? rowIndexManager,
    VisibilityManager? visibilityManager,
  }) : cells = cells != null ? Map<String, Cell>.from(cells) : <String, Cell>{},
       mergedCells = mergedCells ?? MergedCellManager(),
       rowIndexManager = rowIndexManager ?? IndexMappingEngine(rowCount),
       visibilityManager = visibilityManager ?? VisibilityManager();

  Sheet copyWith({
    String? id,
    String? name,
    Map<String, Cell>? cells,
    List<double>? columnWidths,
    List<double>? rowHeights,
    int? rowCount,
    int? columnCount,
    int? frozenRows,
    int? frozenColumns,
    MergedCellManager? mergedCells,
    IndexMappingEngine? rowIndexManager,
    VisibilityManager? visibilityManager,
  }) {
    return Sheet(
      id: id ?? this.id,
      name: name ?? this.name,
      cells: cells ?? this.cells,
      columnWidths: columnWidths ?? this.columnWidths,
      rowHeights: rowHeights ?? this.rowHeights,
      rowCount: rowCount ?? this.rowCount,
      columnCount: columnCount ?? this.columnCount,
      frozenRows: frozenRows ?? this.frozenRows,
      frozenColumns: frozenColumns ?? this.frozenColumns,
      mergedCells: mergedCells ?? this.mergedCells,
      rowIndexManager: rowIndexManager ?? this.rowIndexManager,
      visibilityManager: visibilityManager ?? this.visibilityManager,
    );
  }
}

@immutable
class Workbook {
  final String id;
  final String name;
  final List<Sheet> sheets;
  final int activeSheetIndex;
  final int revision;

  const Workbook({
    required this.id,
    required this.name,
    this.sheets = const [],
    this.activeSheetIndex = 0,
    this.revision = 0,
  });

  Sheet get activeSheet => sheets[activeSheetIndex];

  Workbook copyWith({
    String? id,
    String? name,
    List<Sheet>? sheets,
    int? activeSheetIndex,
    int? revision,
  }) {
    return Workbook(
      id: id ?? this.id,
      name: name ?? this.name,
      sheets: sheets ?? this.sheets,
      activeSheetIndex: activeSheetIndex ?? this.activeSheetIndex,
      revision: revision ?? this.revision,
    );
  }
}
