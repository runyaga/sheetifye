import 'package:sheetifye/src/engine/formula/formula_ast.dart';
import 'package:sheetifye/src/domain/entities/workbook.dart';

class FormulaEvaluator implements ASTVisitor<dynamic> {
  final Sheet sheet;
  final dynamic Function(String name, List<dynamic> args) functionResolver;

  FormulaEvaluator({required this.sheet, required this.functionResolver});

  dynamic evaluate(ASTNode node) => node.accept(this);

  @override
  visitLiteral(LiteralNode node) => node.value;

  @override
  visitCellReference(CellReferenceNode node) {
    final cell = sheet.cells['${node.row},${node.col}'];
    final val = cell?.value;
    if (val is num) return val;
    if (val is String) {
      return num.tryParse(val) ?? val;
    }
    return val ?? 0;
  }

  @override
  visitRangeReference(RangeReferenceNode node) {
    final values = [];
    for (int r = node.range.minRow; r <= node.range.maxRow; r++) {
      for (int c = node.range.minCol; c <= node.range.maxCol; c++) {
        final cell = sheet.cells['$r,$c'];
        final val = cell?.value;
        if (val is num) {
          values.add(val);
        } else if (val is String) {
          values.add(num.tryParse(val) ?? val);
        } else {
          values.add(0);
        }
      }
    }
    return values;
  }

  @override
  visitBinaryExpression(BinaryExpressionNode node) {
    final left = evaluate(node.left);
    final right = evaluate(node.right);

    if (left is num && right is num) {
      switch (node.operator) {
        case '+':
          return left + right;
        case '-':
          return left - right;
        case '*':
          return left * right;
        case '/':
          if (right == 0) return '#DIV/0!';
          return left / right;
      }
    }
    return '#VALUE!';
  }

  @override
  visitFunctionCall(FunctionCallNode node) {
    final args = node.arguments.map((a) => evaluate(a)).toList();
    return functionResolver(node.name.toUpperCase(), args);
  }
}
