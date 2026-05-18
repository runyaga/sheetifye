import 'package:flutter_test/flutter_test.dart';
import 'package:sheetifye/src/engine/validation/validation_engine.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Validation Domain Tests', () {
    late ValidationEngine engine;

    setUp(() {
      engine = ValidationEngine();
    });

    test('Should enforce validation constraints on cellular inputs', () {
      // By default, no rules exist, so all inputs are valid
      expect(engine.isValid(0, 0, '100'), isTrue);
      expect(engine.isValid(0, 0, 'Abc'), isTrue);

      // Create a validation rule
      final rule = ValidationRule(
        type: ValidationType.number,
        criteria: null,
        errorMessage: 'Must be a number!',
      );

      engine.setValidation(0, 0, rule);

      expect(engine.isValid(0, 0, 50), isTrue);
      expect(engine.isValid(0, 0, 'text'), isFalse);
      expect(engine.getRule(0, 0)?.errorMessage, 'Must be a number!');
    });
  });
}
