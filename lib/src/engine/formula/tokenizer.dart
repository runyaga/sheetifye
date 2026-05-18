import 'package:sheetifye/src/engine/formula/formula_ast.dart';

class FormulaTokenizer {
  final String input;
  int _pos = 0;

  FormulaTokenizer(this.input);

  List<FormulaToken> tokenize() {
    final tokens = <FormulaToken>[];

    if (!input.startsWith('=')) return [];

    // Skip leading '='
    _pos++;
    tokens.add(FormulaToken(FormulaTokenType.equals, '=', 0));

    while (_pos < input.length) {
      final char = input[_pos];

      if (RegExp(r'\s').hasMatch(char)) {
        _pos++;
        continue;
      }

      if (RegExp(r'[0-9]').hasMatch(char)) {
        tokens.add(_readNumber());
      } else if (RegExp(r'[A-Za-z]').hasMatch(char) ||
          char == "'" ||
          char == "\$") {
        tokens.add(_readIdentifierOrReference());
      } else if (char == '"') {
        tokens.add(_readString());
      } else {
        switch (char) {
          case '+':
            tokens.add(FormulaToken(FormulaTokenType.plus, '+', _pos++));
            break;
          case '-':
            tokens.add(FormulaToken(FormulaTokenType.minus, '-', _pos++));
            break;
          case '*':
            tokens.add(FormulaToken(FormulaTokenType.star, '*', _pos++));
            break;
          case '/':
            tokens.add(FormulaToken(FormulaTokenType.slash, '/', _pos++));
            break;
          case '(':
            tokens.add(FormulaToken(FormulaTokenType.leftParen, '(', _pos++));
            break;
          case ')':
            tokens.add(FormulaToken(FormulaTokenType.rightParen, ')', _pos++));
            break;
          case ',':
            tokens.add(FormulaToken(FormulaTokenType.comma, ',', _pos++));
            break;
          case ':':
            tokens.add(FormulaToken(FormulaTokenType.colon, ':', _pos++));
            break;
          default:
            _pos++; // Skip unknown
        }
      }
    }

    tokens.add(FormulaToken(FormulaTokenType.eof, '', _pos));
    return tokens;
  }

  FormulaToken _readNumber() {
    final start = _pos;
    while (_pos < input.length && RegExp(r'[0-9.]').hasMatch(input[_pos])) {
      _pos++;
    }
    return FormulaToken(
      FormulaTokenType.number,
      input.substring(start, _pos),
      start,
    );
  }

  FormulaToken _readString() {
    final start = _pos++; // Skip opening quote
    while (_pos < input.length && input[_pos] != '"') {
      _pos++;
    }
    _pos++; // Skip closing quote
    return FormulaToken(
      FormulaTokenType.string,
      input.substring(start + 1, _pos - 1),
      start,
    );
  }

  FormulaToken _readIdentifierOrReference() {
    final start = _pos;

    // Check if it starts with a single quote (indicates sheet name with spaces/special characters)
    if (input[_pos] == "'") {
      _pos++; // skip opening single quote
      while (_pos < input.length && input[_pos] != "'") {
        _pos++;
      }
      if (_pos < input.length) {
        _pos++; // skip closing single quote
      }
      if (_pos < input.length && input[_pos] == '!') {
        _pos++; // skip '!'
        // Now read the A1 address part
        while (_pos < input.length &&
            RegExp(r'[A-Za-z0-9$]').hasMatch(input[_pos])) {
          _pos++;
        }
      }
    } else {
      // Normal reading, allow alphanumeric, $, _, and ! for sheet-qualified references
      while (_pos < input.length &&
          RegExp(r'[A-Za-z0-9$_!]').hasMatch(input[_pos])) {
        _pos++;
      }
    }

    final value = input.substring(start, _pos);

    // Support sheet-qualified references, e.g. Sheet1!A1, 'Sheet One'!$A$1, Sheet1!$B$10
    if (RegExp(
      r"^(?:'?[A-Za-z0-9_\s]+'?!)?\$?[A-Z]+\$?[0-9]+$",
    ).hasMatch(value)) {
      return FormulaToken(FormulaTokenType.reference, value, start);
    }

    // Check if it's a standard local reference (e.g., A1, B10)
    if (RegExp(r'^\$?[A-Z]+\$?[0-9]+$').hasMatch(value)) {
      return FormulaToken(FormulaTokenType.reference, value, start);
    }

    // Otherwise treat as function name
    return FormulaToken(FormulaTokenType.function, value, start);
  }
}
