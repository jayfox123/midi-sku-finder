import 'package:flutter_test/flutter_test.dart';
import 'package:midi_sku_finder/main.dart';

void main() {
  testWidgets('App renders home screen title smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const MidiSkuFinderApp());
    expect(find.text('MIDI SKU Finder'), findsOneWidget);
  });
}
