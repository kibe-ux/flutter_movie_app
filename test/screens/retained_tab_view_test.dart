import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moviehub_app/widgets/retained_tab_view.dart';

class _Page extends StatefulWidget {
  const _Page(this.index, this.started);
  final int index;
  final List<int> started;
  @override
  State<_Page> createState() => _PageState();
}

class _PageState extends State<_Page> {
  final controller = TextEditingController();
  @override
  void initState() {
    super.initState();
    widget.started.add(widget.index);
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => TextField(controller: controller);
}

void main() {
  testWidgets('tabs load on first visit and retain input across switches',
      (tester) async {
    final started = <int>[];
    Future<void> show(int index) async {
      await tester.pumpWidget(MaterialApp(
          home: Scaffold(
              body: RetainedTabView(
        index: index,
        itemCount: 3,
        itemBuilder: (_, index) => _Page(index, started),
      ))));
      await tester.pump();
    }

    await show(0);
    expect(started, [0]);
    await tester.enterText(find.byType(TextField), 'Batman');
    await show(1);
    expect(started, [0, 1]);
    final offstage = find.byType(TextField, skipOffstage: false).first;
      expect(TickerMode.valuesOf(tester.element(offstage)).enabled, isFalse);
    await show(0);
    expect(started, [0, 1]);
    expect(tester.widget<TextField>(find.byType(TextField)).controller!.text,
        'Batman');
  });
}
