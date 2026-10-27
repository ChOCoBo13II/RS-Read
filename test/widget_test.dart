import 'package:flutter_test/flutter_test.dart';
import 'package:rs_reader/main.dart';

void main() {
  testWidgets('La home mostra il pulsante Leggi', (tester) async {
    await tester.pumpWidget(const RsReaderApp());
    expect(find.text('Leggi'), findsOneWidget);
  });
}
