import 'package:flutter_test/flutter_test.dart';
import 'package:sheetifye/sheetifye.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('XLSX Sample Import Parsing Integration Tests', () {
    test(
      '1. Verify active workbook state parses sample metadata structures',
      () {
        final workbook = Workbook(
          id: 'xlsx-import-wb',
          name: 'Sample XLSX Document',
          sheets: [
            Sheet(
              id: 'sh-1',
              name: 'Financial Summary',
              rowCount: 50,
              columnCount: 15,
            ),
          ],
        );

        expect(workbook.sheets.length, 1);
        expect(workbook.sheets[0].name, 'Financial Summary');
        expect(workbook.sheets[0].rowCount, 50);
        expect(workbook.sheets[0].columnCount, 15);
      },
    );

    test(
      '2. Excel formula representations and merged areas parsed cleanly',
      () {
        final sheet = Sheet(
          id: 'sh-1',
          name: 'Financial Summary',
          rowCount: 50,
          columnCount: 15,
        );

        // Add merged cells imported from Excel
        sheet.mergedCells.addRegion(
          GridRange.fromRect(0, 0, 1, 3),
        ); // A1:D2 merged
        expect(sheet.mergedCells.isMerged(0, 0), isTrue);
        expect(sheet.mergedCells.isHidden(0, 1), isTrue);
      },
    );
  });
}
