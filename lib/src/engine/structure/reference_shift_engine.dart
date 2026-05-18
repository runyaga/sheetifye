import 'package:sheetifye/src/engine/formula/formula_ast.dart';
import 'package:sheetifye/src/core/utils/grid_utils.dart';
import 'package:sheetifye/src/engine/formula/tokenizer.dart';
import 'package:sheetifye/src/engine/formula/parser.dart';

class ReferenceShiftEngine {
  String shiftFormula(
    String formula, {
    int? rowAt,
    int? rowCount,
    int? colAt,
    int? colCount,
  }) {
    if (!formula.startsWith('=')) return formula;

    try {
      final tokens = FormulaTokenizer(formula).tokenize();
      final ast = FormulaParser(tokens).parse();
      final visitor = _ReferenceShiftVisitor(
        rowAt: rowAt,
        rowCount: rowCount ?? 0,
        colAt: colAt,
        colCount: colCount ?? 0,
      );
      return '=${ast.accept(visitor)}';
    } catch (e) {
      return formula; // Return original if parsing fails during shift
    }
  }
}

class _ReferenceShiftVisitor implements ASTVisitor<String> {
  final int? rowAt;
  final int rowCount;
  final int? colAt;
  final int colCount;

  _ReferenceShiftVisitor({
    this.rowAt,
    this.rowCount = 0,
    this.colAt,
    this.colCount = 0,
  });

  @override
  String visitLiteral(LiteralNode node) {
    if (node.value is String) return '"${node.value}"';
    return node.value.toString();
  }

  @override
  String visitCellReference(CellReferenceNode node) {
    // Check for sheet prefix and parse the cell coordinate part of the address
    final parts = node.address.split('!');
    final cellAddr = parts.last; // e.g. "$A$1" or "A1"

    // Column lock: has $ before letters, e.g., $A1 or $A$1
    final colLocked = cellAddr.startsWith('\$');
    // Row lock: has $ before digits, e.g., A$1 or $A$1
    final rowLocked = cellAddr.substring(colLocked ? 1 : 0).contains('\$');

    int r = node.row;
    int c = node.col;

    if (!rowLocked && rowAt != null && r >= rowAt!) {
      r += rowCount;
    }
    if (!colLocked && colAt != null && c >= colAt!) {
      c += colCount;
    }

    if (r < 0 || c < 0) return '#REF!';

    // Reconstruct sheet prefix
    String prefix = '';
    if (node.address.contains('!')) {
      final idx = node.address.indexOf('!');
      prefix = node.address.substring(0, idx + 1);
    }

    String colStr = colLocked ? '\$' : '';
    String rowStr = rowLocked ? '\$' : '';

    final newAddressWithoutLocks = GridUtils.getAddress(r, c); // e.g., "C4"
    final match = RegExp(
      r'^([A-Z]+)([0-9]+)$',
    ).firstMatch(newAddressWithoutLocks);
    if (match != null) {
      final colLetter = match.group(1)!;
      final rowNum = match.group(2)!;
      return '$prefix$colStr$colLetter$rowStr$rowNum';
    }

    return '$prefix$newAddressWithoutLocks';
  }

  @override
  String visitRangeReference(RangeReferenceNode node) {
    int minR = node.range.minRow;
    int maxR = node.range.maxRow;
    int minC = node.range.minCol;
    int maxC = node.range.maxCol;

    if (rowAt != null) {
      if (minR >= rowAt!) minR += rowCount;
      if (maxR >= rowAt!) maxR += rowCount;
    }
    if (colAt != null) {
      if (minC >= colAt!) minC += colCount;
      if (maxC >= colAt!) maxC += colCount;
    }

    if (minR < 0 || minC < 0) return '#REF!';

    // Extract optional sheet prefix e.g., Sheet1! or 'Sheet One'!
    String prefix = '';
    if (node.address.contains('!')) {
      final idx = node.address.indexOf('!');
      prefix = node.address.substring(0, idx + 1);
    }
    return '$prefix${GridUtils.getAddress(minR, minC)}:$prefix${GridUtils.getAddress(maxR, maxC)}';
  }

  @override
  String visitBinaryExpression(BinaryExpressionNode node) {
    return '(${node.left.accept(this)} ${node.operator} ${node.right.accept(this)})';
  }

  @override
  String visitFunctionCall(FunctionCallNode node) {
    final args = node.arguments.map((a) => a.accept(this)).join(',');
    return '${node.name}($args)';
  }
}
