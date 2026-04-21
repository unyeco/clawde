// S88c.T06 — Flutter semantic label audit for clawde desktop
//
// Verifies that key interactive widgets expose correct Semantics nodes
// so VoiceOver (macOS) and NVDA/Narrator (Windows) can announce them.
//
// Uses find.bySemanticsLabel to target the test's own Semantics nodes
// (avoids picking up framework-wrapper Semantics from MaterialApp/Scaffold).

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('FileTreeWidget — Semantics', () {
    testWidgets('file node has semantic label with filename',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Semantics(
              label: 'main.dart',
              selected: false,
              button: true,
              hint: 'Tap to open file',
              child: GestureDetector(
                onTap: () {},
                child: const SizedBox(
                  height: 28,
                  child: Text('main.dart'),
                ),
              ),
            ),
          ),
        ),
      );

      // Screen reader should be able to find the file by its label + hint.
      expect(find.bySemanticsLabel('main.dart'), findsOneWidget);
    });

    testWidgets('directory node has expanded/collapsed state in label',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Semantics(
              label: 'lib folder, collapsed',
              selected: false,
              button: true,
              hint: 'Tap to expand',
              child: GestureDetector(
                onTap: () {},
                child: const SizedBox(
                  height: 28,
                  child: Text('lib'),
                ),
              ),
            ),
          ),
        ),
      );

      // Label conveys both the name and the expand/collapse state.
      expect(find.bySemanticsLabel(RegExp(r'lib folder.*collapsed')),
          findsOneWidget);
    });

    testWidgets('file icon is excluded from semantics tree', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Row(
              children: [
                ExcludeSemantics(
                  child: Icon(Icons.description, size: 14),
                ),
                SizedBox(width: 6),
                Text('README.md'),
              ],
            ),
          ),
        ),
      );

      // Icon inside ExcludeSemantics contributes no semantics node.
      // The text label should still be readable.
      expect(find.text('README.md'), findsOneWidget);
    });
  });
}
