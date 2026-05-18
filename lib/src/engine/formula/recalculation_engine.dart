import 'package:sheetifye/src/domain/entities/workbook.dart';
import 'package:sheetifye/src/engine/formula/function_registry.dart';

import 'package:sheetifye/src/engine/formula/tokenizer.dart';
import 'package:sheetifye/src/engine/formula/parser.dart';
import 'package:sheetifye/src/engine/formula/evaluator.dart';
import 'package:sheetifye/src/engine/formula/dependency_graph.dart';
import 'package:sheetifye/src/engine/formula/formula_ast.dart';

class RecalculationEngine {
  final DependencyGraph _graph = DependencyGraph();
  final FunctionRegistry _functionRegistry = FunctionRegistry();
  final Map<String, ASTNode> _astCache = {};

  RecalculationEngine();

  void processCellUpdate(
    String cellAddress,
    String input,
    Sheet sheet,
    void Function(String, dynamic) onValueComputed,
  ) {
    if (input.startsWith('=')) {
      try {
        final tokens = FormulaTokenizer(input).tokenize();
        final ast = FormulaParser(tokens).parse();
        _astCache[cellAddress] = ast;

        // Extract dependencies from AST
        final dependencies = _extractDependencies(ast);
        _graph.updateDependencies(cellAddress, dependencies);

        // Recalculate this cell and its dependents
        _recalculate(cellAddress, sheet, onValueComputed);
      } on CircularDependencyException {
        onValueComputed(cellAddress, '#REF!');
        rethrow;
      } catch (e) {
        onValueComputed(cellAddress, '#ERROR!');
      }
    } else {
      _astCache.remove(cellAddress);
      _graph.updateDependencies(cellAddress, {});
      onValueComputed(cellAddress, input);

      // Still need to trigger dependents
      final dependents = _graph.getAllDependents(cellAddress);
      for (final dep in dependents) {
        _recalculate(dep, sheet, onValueComputed);
      }
    }
  }

  void _recalculate(
    String cellAddress,
    Sheet sheet,
    void Function(String, dynamic) onValueComputed,
  ) {
    final order = _graph.getRecalculationOrder(cellAddress);

    final evaluator = FormulaEvaluator(
      sheet: sheet,
      functionResolver: (name, args) => _functionRegistry.execute(name, args),
    );

    for (final addr in order) {
      final ast = _astCache[addr];
      if (ast != null) {
        final result = evaluator.evaluate(ast);
        onValueComputed(addr, result);
      }
    }
  }

  Set<String> _extractDependencies(ASTNode node) {
    final deps = <String>{};
    final visitor = _DependencyVisitor(deps);
    node.accept(visitor);
    return deps;
  }
}

class _DependencyVisitor extends ASTVisitor<void> {
  final Set<String> dependencies;
  _DependencyVisitor(this.dependencies);

  @override
  visitLiteral(node) {}
  @override
  visitCellReference(node) => dependencies.add('${node.row},${node.col}');
  @override
  visitRangeReference(node) {
    for (int r = node.range.minRow; r <= node.range.maxRow; r++) {
      for (int c = node.range.minCol; c <= node.range.maxCol; c++) {
        dependencies.add('$r,$c');
      }
    }
  }

  @override
  visitBinaryExpression(node) {
    node.left.accept(this);
    node.right.accept(this);
  }

  @override
  visitFunctionCall(node) {
    for (final arg in node.arguments) {
      arg.accept(this);
    }
  }
}
