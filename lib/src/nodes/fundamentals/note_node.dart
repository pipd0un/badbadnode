// lib/nodes/fundamentals/note_node.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/node.dart';
import '../../core/evaluator.dart';
import '../simple_node.dart';

class NoteNode extends SimpleNode {
  NoteNode()
    : super(
        extraData: {'text': 'Note here ..', 'width': 160.0, 'height': 50.0},
      );

  @override
  String get type => 'note';
  @override
  List<String> get inputs => const [];
  @override
  List<String> get outputs => const [];
  @override
  Future run(Node _, GraphEvaluator __) async => null; // ignored

  @override
  Widget buildWidget(Node node, WidgetRef ref) =>
      _StickyNote(node: node, ref: ref);
}

class _StickyNote extends StatefulWidget {
  const _StickyNote({required this.node, required this.ref});
  final Node node;
  final WidgetRef ref;

  static const int _maxLineLength = 50;
  static const int _maxLines = 15;
  static const Size _min = Size(160, 50);
  static const Size _max = Size(400, 300);
  static const _pad = EdgeInsets.fromLTRB(28, 8, 8, 8);

  @override
  State<_StickyNote> createState() => _StickyNoteState();
}

class _StickyNoteState extends State<_StickyNote> {
  late double _width;
  late double _height;

  @override
  void initState() {
    super.initState();
    final data = widget.node.data;
    _width = (data['width'] as num?)?.toDouble() ?? _StickyNote._min.width;
    _height = (data['height'] as num?)?.toDouble() ?? _StickyNote._min.height;
  }

  String _wrapLine(String line) {
    if (line.length <= _StickyNote._maxLineLength) return line;
    final buf = StringBuffer();
    for (var i = 0; i < line.length; i += _StickyNote._maxLineLength) {
      final end =
          (i + _StickyNote._maxLineLength < line.length)
              ? i + _StickyNote._maxLineLength
              : line.length;
      buf.write(line.substring(i, end));
      if (end < line.length) buf.write('\n');
    }
    return buf.toString();
  }

  Future<void> _edit(BuildContext context) async {
    final text = widget.node.data['text'] as String? ?? '';
    final ctl = TextEditingController(text: text);
    final res = await showDialog<String?>(
      context: context,
      builder:
          (ctx) => AlertDialog(
            backgroundColor: const Color(0xFFFFF9C4),
            contentPadding: EdgeInsets.zero,
            content: SizedBox(
              width: 400,
              height: 260,
              child: Stack(
                children: [
                  const Positioned.fill(child: CustomPaint(painter: _Paper())),
                  Padding(
                    padding: _StickyNote._pad,
                    child: TextField(
                      controller: ctl,
                      maxLines: null,
                      decoration: const InputDecoration(
                        border: InputBorder.none,
                      ),
                      style: const TextStyle(fontSize: 14, height: 1.3),
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, null),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(ctx, ctl.text),
                child: const Text('Save'),
              ),
            ],
          ),
    );
    if (res != null && res != text) {
      NodeActions.updateData(widget.ref, widget.node.id, 'text', res);
    }
  }

  @override
  Widget build(BuildContext context) {
    final raw = widget.node.data['text'] as String? ?? '';
    final wrappedLines =
        raw.split('\n').expand((l) => _wrapLine(l).split('\n')).toList();
    final lines =
        wrappedLines.length > _StickyNote._maxLines
            ? [...wrappedLines.take(_StickyNote._maxLines - 1), '...']
            : wrappedLines;
    final display = lines.isEmpty ? '<empty>' : lines.join('\n');

    return GestureDetector(
      onDoubleTap: () => _edit(context),
      onLongPress: () => _edit(context),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        clipBehavior: Clip.hardEdge,
        child: SizedBox(
          width: _width,
          height: _height,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: const Color(0xFFFFF9C4),
              borderRadius: BorderRadius.circular(8),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x55000000),
                  offset: Offset(2, 2),
                  blurRadius: 3,
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Stack(
                children: [
                  const Positioned.fill(child: CustomPaint(painter: _Paper())),
                  Padding(
                    padding: _StickyNote._pad,
                    child: Text(
                      display,
                      style: const TextStyle(fontSize: 14, height: 1.3),
                    ),
                  ),
                  Align(
                    alignment: Alignment.bottomRight,
                    child: Padding(
                      padding: const EdgeInsets.all(4),
                      child: GestureDetector(
                        behavior: HitTestBehavior.translucent,
                        onPanUpdate: (d) {
                          setState(() {
                            _width = (_width + d.delta.dx).clamp(
                              _StickyNote._min.width,
                              _StickyNote._max.width,
                            );
                            _height = (_height + d.delta.dy).clamp(
                              _StickyNote._min.height,
                              _StickyNote._max.height,
                            );
                          });
                        },
                        onPanEnd: (_) {
                          NodeActions.updateData(
                            widget.ref,
                            widget.node.id,
                            'width',
                            _width,
                          );
                          NodeActions.updateData(
                            widget.ref,
                            widget.node.id,
                            'height',
                            _height,
                          );
                        },
                        onPanCancel: () {
                          NodeActions.updateData(
                            widget.ref,
                            widget.node.id,
                            'width',
                            _width,
                          );
                          NodeActions.updateData(
                            widget.ref,
                            widget.node.id,
                            'height',
                            _height,
                          );
                        },
                        child: const Icon(
                          Icons.open_in_full,
                          size: 16,
                          color: Color.fromARGB(255, 255, 107, 156),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Paper extends CustomPainter {
  const _Paper();

  static const _bg = Color(0xFFFFF9C4);
  static const _line = Color(0xFFDDDDA3);
  static const _margin = Color(0xFFCC6666);

  @override
  void paint(Canvas canvas, Size size) {
    final bgPaint = Paint()..color = _bg;
    canvas.drawRect(Offset.zero & size, bgPaint);
    final linePaint =
        Paint()
          ..color = _line
          ..strokeWidth = 1;
    const step = 18.0;
    for (double y = step; y < size.height; y += step) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), linePaint);
    }
    final marginPaint =
        Paint()
          ..color = _margin
          ..strokeWidth = 1;
    canvas.drawLine(const Offset(24, 0), Offset(24, size.height), marginPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
