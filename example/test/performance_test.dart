// test/performance_500_nodes_test.dart
import 'dart:ui';

import 'package:example/main.dart' show NodeEditorApp;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:badbad/node.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('500-node canvas keeps ≥30 fps while panning', (
    WidgetTester tester,
  ) async {
    // 1) seed the graph with 500 nodes
    final graph = GraphController()..clear();
    const cols = 25; // 25 × 20 = 500
    for (var i = 0; i < 500; i++) {
      graph.addNodeOfType('number', (i % cols) * 200.0, (i ~/ cols) * 120.0);
    }

    // 2) pump the app *inside* a ProviderScope
    await tester.pumpWidget(const ProviderScope(child: NodeEditorApp()));
    await tester.pumpAndSettle(const Duration(milliseconds: 200));

    // 3) grab the InteractiveViewer’s controller
    final ivFinder = find.byType(InteractiveViewer);
    expect(ivFinder, findsOneWidget);
    final iv = tester.widget<InteractiveViewer>(ivFinder);
    final ctrl = iv.transformationController!;

    // 4) record frame timings
    final spans = <Duration>[];
    TimingsCallback cb;
    cb = (List<FrameTiming> list) => spans.addAll(list.map((t) => t.totalSpan));
    tester.binding.addTimingsCallback(cb);

    // 5) simulate a slow three-second pan (-200 → 0 px on X)
    const steps = 120; // 3 s / 25 ms
    for (var i = 0; i < steps; i++) {
      ctrl.value = Matrix4.identity()..translate(-200.0 * (i / steps), 0.0);
      await tester.pump(const Duration(milliseconds: 25));
    }

    await tester.pumpAndSettle(const Duration(milliseconds: 200));
    tester.binding.removeTimingsCallback(cb);

    // 6) assert no frame > 33 ms  (≈30 fps)
    final worst =
        spans.isEmpty ? Duration.zero : spans.reduce((a, b) => a > b ? a : b);
    expect(
      worst.inMilliseconds,
      lessThanOrEqualTo(33),
      reason:
          'A frame took ${worst.inMilliseconds} ms (> 33 ms) with 500 nodes → perf regression',
    );
  });
}
