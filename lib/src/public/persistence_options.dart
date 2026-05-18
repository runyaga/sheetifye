import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sheetifye/src/domain/entities/workbook.dart';

final persistenceOptionsProvider = Provider<PersistenceOptions?>((ref) => null);

class PersistenceOptions {
  final Future<bool> Function(Workbook workbook)? onSave;
  final Future<bool> Function(Workbook workbook)? onSaveAs;
  final Future<bool> Function()? onBeforeClose;
  final VoidCallback? onDiscardChanges;
  final void Function(Workbook workbook, bool isDirty)? onWorkbookChanged;

  const PersistenceOptions({
    this.onSave,
    this.onSaveAs,
    this.onBeforeClose,
    this.onDiscardChanges,
    this.onWorkbookChanged,
  });
}
