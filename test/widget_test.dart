import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:rs_reader/app.dart';
import 'package:rs_reader/parser.dart';
import 'package:rs_reader/tick_sound_data.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('La home mostra il pulsante di lettura', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(const RsReaderApp());
    await tester.pump();
    expect(find.text("Leggi dall'inizio"), findsOneWidget);
  });

  test('parseText divide in paragrafi con riga vuota', () {
    final r = parseText('Ciao mondo.\n\nSecondo paragrafo qui.');
    expect(r.words.length, 5);
    expect(r.starts, [0, 2]);
  });

  test('parseText usa gli a capo se non ci sono righe vuote', () {
    final r = parseText('a b\nc d');
    expect(r.words.length, 4);
    expect(r.starts, [0, 2]);
  });

  test('il WAV incorporato è integro', () {
    final b = base64Decode(tickWavBase64);
    expect(b.length, 1388);
    expect(String.fromCharCodes(b.sublist(0, 4)), 'RIFF');
    expect(String.fromCharCodes(b.sublist(8, 12)), 'WAVE');
    expect(b.fold<int>(0, (a, x) => a + x), 175996);
  });
}