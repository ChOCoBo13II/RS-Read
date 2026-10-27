import 'package:flutter_test/flutter_test.dart';
import 'package:rs_reader/main.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('La home mostra il pulsante di lettura', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(const RsReaderApp());
    await tester.pump();
    expect(find.text("Leggi dall'inizio"), findsOneWidget);
  });
}
