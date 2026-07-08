import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('renders a basic Flutter screen', (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Center(child: Text('Asphixia')),
        ),
      ),
    );

    expect(find.text('Asphixia'), findsOneWidget);
  });
}
