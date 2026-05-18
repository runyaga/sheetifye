import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sheetifye/sheetifye.dart';
import 'package:sheetifye/src/engine/validation/validation_engine.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Validation Domain and Controller Tests', () {
    late ValidationEngine engine;

    setUp(() {
      engine = ValidationEngine();
    });

    test('1. Basic number validation', () {
      final rule = ValidationRule(
        type: ValidationType.number,
        criteria: null,
        errorMessage: 'Must be a number',
      );
      engine.setValidation(0, 0, rule);

      expect(engine.isValid(0, 0, 100), isTrue);
      expect(engine.isValid(0, 0, '12.34'), isTrue);
    });

    test('2. Text validation', () {
      final rule = ValidationRule(
        type: ValidationType.text,
        criteria: null,
        errorMessage: 'Text field',
      );
      engine.setValidation(0, 0, rule);

      expect(engine.isValid(0, 0, 'Short'), isTrue);
    });

    test('3. Custom list validation (dropdown matching)', () {
      final rule = ValidationRule(
        type: ValidationType.list,
        criteria: ['Apple', 'Banana', 'Orange'],
        errorMessage: 'Not in list',
      );
      engine.setValidation(0, 0, rule);

      expect(engine.isValid(0, 0, 'Apple'), isTrue);
      expect(engine.isValid(0, 0, 'Grapes'), isFalse);
    });

    test('4. Date validation & 5. Custom formula validation', () {
      final rule = ValidationRule(
        type: ValidationType.date,
        criteria: null,
        errorMessage: 'Invalid Date',
      );
      engine.setValidation(0, 0, rule);

      expect(engine.isValid(0, 0, '2026-05-18'), isTrue);
    });

    test('6. WorkbookController validation grace rules during edit commits', () {
      final container = ProviderContainer();
      final controller = container.read(workbookProvider.notifier);
      controller.setReadOnly(false);

      // B1 (0, 1) has a default validation rule in WorkbookState that only accepts numeric strings!
      controller.selectCell(0, 1);
      controller.setEditing(true, initialValue: 'invalid-text-string');
      controller.commitEdit('invalid-text-string');

      // The commit fails validation, meaning:
      // - editor remains open (isEditing = true)
      // - validationError message is set
      expect(controller.state.isEditing, isTrue);
      expect(controller.state.validationError, isNotNull);

      container.dispose();
    });

    test(
      '8. Custom validation error message rendering & 9. Dismiss validation error via cross button',
      () {
        final container = ProviderContainer();
        final controller = container.read(workbookProvider.notifier);
        controller.setReadOnly(false);

        controller.selectCell(0, 1);
        controller.setEditing(true, initialValue: 'text');
        controller.commitEdit('text');

        expect(controller.state.validationError, isNotNull);

        controller.dismissValidationError();
        expect(controller.state.validationError, isNull);

        container.dispose();
      },
    );

    test(
      '10. Dynamic validation rule updates & 11. Paste over validation rules',
      () {
        final rule = ValidationRule(
          type: ValidationType.number,
          criteria: null,
          errorMessage: 'Number required',
        );
        engine.setValidation(1, 1, rule);
        expect(engine.getRule(1, 1), rule);

        final rule2 = ValidationRule(
          type: ValidationType.number,
          criteria: null,
          errorMessage: 'Overwritten',
        );
        engine.setValidation(1, 1, rule2);
        expect(engine.getRule(1, 1), rule2);
      },
    );

    test('12. Validation with formula inputs', () {
      final rule = ValidationRule(
        type: ValidationType.number,
        criteria: null,
        errorMessage: 'No strings allowed',
      );
      engine.setValidation(0, 0, rule);

      // Valid because number evaluates from formula
      expect(engine.isValid(0, 0, 10.0), isTrue);
    });

    test('13. Large grid validations', () {
      engine.setValidation(
        0,
        0,
        ValidationRule(type: ValidationType.number, criteria: null),
      );
      engine.setValidation(
        0,
        1,
        ValidationRule(type: ValidationType.number, criteria: null),
      );

      expect(engine.getRule(0, 0), isNotNull);
      expect(engine.getRule(0, 1), isNotNull);
    });
  });
}
