import 'package:flutter/material.dart';

/// Mount tabs on first visit, then keep their data and scroll positions.
class RetainedTabView extends StatefulWidget {
  const RetainedTabView(
      {super.key,
      required this.index,
      required this.itemCount,
      required this.itemBuilder});

  final int index;
  final int itemCount;
  final IndexedWidgetBuilder itemBuilder;

  @override
  State<RetainedTabView> createState() => _RetainedTabViewState();
}

class _RetainedTabViewState extends State<RetainedTabView> {
  final _visited = <int>{};

  @override
  Widget build(BuildContext context) {
    _visited.add(widget.index);
    return IndexedStack(index: widget.index, children: [
      for (var index = 0; index < widget.itemCount; index++)
        if (_visited.contains(index))
          TickerMode(
              enabled: index == widget.index,
              child: ExcludeFocus(
                  excluding: index != widget.index,
                  child: RepaintBoundary(
                      child: widget.itemBuilder(context, index))))
        else
          const SizedBox.shrink(),
    ]);
  }
}
