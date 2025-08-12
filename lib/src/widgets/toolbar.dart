// lib/widgets/toolbar.dart
//
// Thinner, desktop-like app bar with a bottom tab strip.
// Adds a “New” menu (Blueprint) and a tabs row under the AppBar.
// Run/eval and all actions operate on the *active* tab.
// UPDATE: Double-tap a tab to rename it inline. Editing auto-saves on Enter
// or when focus is lost. Esc cancels and restores the old name.
// UPDATE-2: Replaced deprecated RawKeyboardListener usage with modern
// Shortcuts/Actions + SingleActivator to handle Esc while editing.
// UPDATE-3: Limit rebuild listeners to high-level events only (GraphChanged,
//           ActiveBlueprintChanged, BlueprintOpened/Closed/Renamed) to avoid
//           per-node storm setState() calls that slowed tab switch/close.

import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../controller/graph_controller.dart';
import '../core/graph_events.dart'
    show
        GraphChanged,
        ActiveBlueprintChanged,
        BlueprintOpened,
        BlueprintClosed,
        BlueprintRenamed;
import '../providers/graph_controller_provider.dart' show graphControllerProvider;
import '../providers/app_providers.dart' show scaffoldMessengerKeyProvider;
import '../providers/asset_provider.dart' show assetFilesProvider;
import '../providers/ui/selection_providers.dart' show selectedNodesProvider;

class Toolbar extends ConsumerStatefulWidget implements PreferredSizeWidget {
  const Toolbar({super.key});
  @override
  Size get preferredSize => const Size.fromHeight(60.0); // 32 (top) + 28 (tabs)
  @override
  createState() => _ToolbarState();
}

class _ToolbarState extends ConsumerState<Toolbar> {
  late final GraphController _graph;
  late final List<StreamSubscription> _subs;

  static const double _topBarHeight = 32.0;
  static const double _tabBarHeight = 28.0;

  @override
  void initState() {
    super.initState();
    _graph = ref.read(graphControllerProvider);
    _subs = [
      _graph.on<GraphChanged>().listen((_) => setState(() {})),
      _graph.on<ActiveBlueprintChanged>().listen((_) => setState(() {})),
      _graph.on<BlueprintOpened>().listen((_) => setState(() {})),
      _graph.on<BlueprintClosed>().listen((_) => setState(() {})),
      _graph.on<BlueprintRenamed>().listen((_) => setState(() {})),
    ];
  }

  @override
  void dispose() {
    for (final s in _subs) {
      s.cancel();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final messenger = ref.read(scaffoldMessengerKeyProvider);
    final hasAssets = ref.watch(assetFilesProvider).isNotEmpty;
    final sel = ref.watch(selectedNodesProvider);

    Future<void> showPasteJsonDialog() async {
      final controller = TextEditingController();
      final result = await showDialog<String>(
        context: context,
        builder: (context) {
          return AlertDialog(
            title: const Text('Paste JSON'),
            content: SizedBox(
              width: 500,
              height: 300,
              child: TextField(
                controller: controller,
                maxLines: null,
                expands: true,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  hintText: 'Paste JSON here…',
                ),
                style: const TextStyle(fontSize: 12),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(null),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.of(context).pop(controller.text),
                child: const Text('OK'),
              ),
            ],
          );
        },
      );

      if (result == null || result.trim().isEmpty) return;

      try {
        final parsed = jsonDecode(result);
        if (parsed is! Map ||
            parsed['nodes'] is! List ||
            parsed['connections'] is! List) {
          throw const FormatException('Missing "nodes" or "connections"');
        }

        _graph.loadJsonMap(parsed.cast<String, dynamic>());
        messenger.currentState?.showSnackBar(
          const SnackBar(
            content: Text('JSON loaded from dialog'),
            duration: Duration(milliseconds: 600),
          ),
        );
      } catch (e) {
        messenger.currentState?.showSnackBar(
          SnackBar(
            content: Text('Invalid JSON: $e'),
            duration: const Duration(milliseconds: 1200),
          ),
        );
      }
    }

    const double iconSz = 18.0;
    return AppBar(
      toolbarHeight: _topBarHeight,
      backgroundColor: const Color.fromARGB(255, 41, 40, 40),
      title: const Text(
        'Node Editor',
        style: TextStyle(
          fontSize: 14,
          color: Color.fromARGB(255, 255, 116, 116),
        ),
      ),
      titleSpacing: 8,
      actions: [
        // NEW TAB SECTION (menu)
        PopupMenuButton<String>(
          tooltip: 'New',
          icon: const Icon(
            Icons.add_box,
            color: Color.fromARGB(255, 255, 119, 230),
          ),
          itemBuilder: (ctx) => const [
            PopupMenuItem<String>(
              value: 'blueprint',
              child: Text('Blueprint'),
            ),
          ],
          onSelected: (v) {
            if (v == 'blueprint') {
              _graph.newBlueprint();
            }
          },
        ),

        VerticalDivider(
          color: const Color.fromARGB(255, 255, 90, 90),
          thickness: 1,
          width: 8,
          indent: 6,
          endIndent: 6,
        ),

        IconButton(
          iconSize: iconSz,
          icon: const Icon(
            Icons.undo,
            color: Color.fromARGB(255, 255, 119, 230),
          ),
          tooltip: 'Undo',
          onPressed: _graph.canUndo ? _graph.undo : null,
        ),
        IconButton(
          iconSize: iconSz,
          icon: const Icon(
            Icons.redo,
            color: Color.fromARGB(255, 255, 119, 230),
          ),
          tooltip: 'Redo',
          onPressed: _graph.canRedo ? _graph.redo : null,
        ),

        VerticalDivider(
          color: const Color.fromARGB(255, 255, 90, 90),
          thickness: 1,
          width: 8,
          indent: 6,
          endIndent: 6,
        ),

        IconButton(
          iconSize: iconSz,
          tooltip: 'Run graph (active tab)',
          icon: const Icon(
            Icons.play_arrow,
            color: Color.fromARGB(255, 255, 119, 230),
          ),
          onPressed: () async {
            await _graph.evaluate();
            messenger.currentState?.showSnackBar(
              const SnackBar(
                content: Text('Evaluation finished'),
                duration: Duration(milliseconds: 500),
              ),
            );
          },
        ),

        VerticalDivider(
          color: const Color.fromARGB(255, 255, 90, 90),
          thickness: 1,
          width: 8,
          indent: 6,
          endIndent: 6,
        ),

        IconButton(
          iconSize: iconSz,
          tooltip: 'Select All',
          icon: const Icon(
            Icons.select_all,
            color: Color.fromARGB(255, 255, 119, 230),
          ),
          onPressed: () =>
              ref.read(selectedNodesProvider.notifier).selectAll(_graph.nodes.keys.toList()),
        ),
        IconButton(
          iconSize: iconSz,
          tooltip: 'Clear All',
          icon: const Icon(
            Icons.clear_all,
            color: Color.fromARGB(255, 255, 119, 230),
          ),
          onPressed: () {
            _graph.clear();
            ref.read(selectedNodesProvider.notifier).clear();
          },
        ),

        VerticalDivider(
          color: const Color.fromARGB(255, 255, 90, 90),
          thickness: 1,
          width: 8,
          indent: 6,
          endIndent: 6,
        ),

        IconButton(
          iconSize: iconSz,
          tooltip: 'Copy',
          icon: const Icon(
            Icons.copy,
            color: Color.fromARGB(255, 255, 119, 230),
          ),
          onPressed: sel.isNotEmpty ? () => _graph.copyNodes(sel) : null,
        ),
        IconButton(
          iconSize: iconSz,
          tooltip: 'Cut',
          icon: const Icon(
            Icons.content_cut,
            color: Color.fromARGB(255, 255, 119, 230),
          ),
          onPressed: sel.isNotEmpty
              ? () {
                  _graph.cutNodes(sel);
                  ref.read(selectedNodesProvider.notifier).clear();
                }
              : null,
        ),
        IconButton(
          iconSize: iconSz,
          tooltip: 'Paste (into active tab)',
          icon: const Icon(
            Icons.paste,
            color: Color.fromARGB(255, 255, 119, 230),
          ),
          onPressed: () => _graph.pasteClipboard(100, 100),
        ),

        VerticalDivider(
          color: const Color.fromARGB(255, 255, 90, 90),
          thickness: 1,
          width: 8,
          indent: 6,
          endIndent: 6,
        ),

        TextButton.icon(
          icon: Icon(
            hasAssets ? Icons.eject : Icons.folder_open,
            color: const Color.fromARGB(255, 255, 119, 230),
            size: iconSz,
          ),
          label: const Text(
            // thinner label
            '',
            style: TextStyle(color: Colors.white, fontSize: 12),
          ),
          onPressed: hasAssets
              ? () => ref.read(assetFilesProvider.notifier).clear()
              : () => ref.read(assetFilesProvider.notifier).loadAssets(),
          style: TextButton.styleFrom(
            minimumSize: const Size(28, 28),
            padding: const EdgeInsets.symmetric(horizontal: 6),
          ),
        ),

        VerticalDivider(
          color: const Color.fromARGB(255, 255, 90, 90),
          thickness: 1,
          width: 8,
          indent: 6,
          endIndent: 6,
        ),

        IconButton(
          iconSize: iconSz,
          tooltip: 'Copy JSON',
          icon: const Icon(
            Icons.copy_all,
            color: Color.fromARGB(255, 255, 119, 230),
          ),
          onPressed: () {
            Clipboard.setData(ClipboardData(text: jsonEncode(_graph.toJson())));
            messenger.currentState?.showSnackBar(
              const SnackBar(
                content: Text('Blueprint copied'),
                duration: Duration(milliseconds: 500),
              ),
            );
          },
        ),

        IconButton(
          iconSize: iconSz,
          tooltip: 'Paste JSON',
          icon: const Icon(
            Icons.paste,
            color: Color.fromARGB(255, 255, 119, 230),
          ),
          onPressed: () {
            if (kIsWeb) {
              showPasteJsonDialog();
            } else {
              Clipboard.getData('text/plain').then((data) {
                try {
                  final raw = jsonDecode(data?.text ?? '{}');
                  if (raw is! Map ||
                      raw['nodes'] is! List ||
                      raw['connections'] is! List) {
                    throw FormatException('Missing "nodes" or "connections"');
                  }
                  _graph.loadJsonMap(raw.cast<String, dynamic>());
                  messenger.currentState?.showSnackBar(
                    const SnackBar(
                      content: Text('JSON loaded'),
                      duration: Duration(milliseconds: 500),
                    ),
                  );
                } catch (e) {
                  messenger.currentState?.showSnackBar(
                    SnackBar(
                      content: Text('Invalid JSON: $e'),
                      duration: const Duration(milliseconds: 1000),
                    ),
                  );
                }
              });
            }
          },
        ),

        IconButton(
          iconSize: iconSz,
          tooltip: 'Load JSON',
          icon: const Icon(
            Icons.upload_file,
            color: Color.fromARGB(255, 255, 119, 230),
          ),
          onPressed: () async {
            await _graph.loadJsonFromFile();
            messenger.currentState?.showSnackBar(
              const SnackBar(
                content: Text('File loaded'),
                duration: Duration(milliseconds: 500),
              ),
            );
          },
        ),

        const SizedBox(width: 12),
      ],
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(_tabBarHeight),
        child: _TabsStrip(controller: _graph, height: _tabBarHeight),
      ),
    );
  }
}

class _TabsStrip extends StatelessWidget {
  final GraphController controller;
  final double height;
  const _TabsStrip({required this.controller, required this.height});

  @override
  Widget build(BuildContext context) {
    final tabs = controller.tabs;
    final active = controller.activeBlueprintId;

    return Container(
      color: const Color.fromARGB(255, 36, 35, 35),
      height: height,
      child: Row(
        children: [
          const SizedBox(width: 4),
          IconButton(
            tooltip: 'New Blueprint',
            icon: const Icon(
              Icons.add,
              size: 16,
              color: Color.fromARGB(255, 255, 119, 230),
            ),
            onPressed: () => controller.newBlueprint(),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints.tightFor(width: 28, height: 28),
          ),
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  const SizedBox(width: 6),
                  for (final t in tabs)
                    _TabChip(
                      id: t.id,
                      title: t.title,
                      isActive: t.id == active,
                      controller: controller,
                    ),
                  const SizedBox(width: 6),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TabChip extends StatefulWidget {
  final String id;
  final String title;
  final bool isActive;
  final GraphController controller;

  const _TabChip({
    required this.id,
    required this.title,
    required this.isActive,
    required this.controller,
  });

  @override
  State<_TabChip> createState() => _TabChipState();
}

class _TabChipState extends State<_TabChip> {
  bool _editing = false;
  late TextEditingController _ctl;
  final FocusNode _focus = FocusNode();

  @override
  void initState() {
    super.initState();
    _ctl = TextEditingController(text: widget.title);
    _focus.addListener(() {
      if (!_focus.hasFocus && _editing) {
        _commit();
      }
    });
  }

  @override
  void didUpdateWidget(covariant _TabChip oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_editing && widget.title != _ctl.text) {
      _ctl.text = widget.title;
    }
  }

  @override
  void dispose() {
    _ctl.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _startEdit() {
    setState(() {
      _editing = true;
      _ctl.selection = TextSelection(
        baseOffset: 0,
        extentOffset: _ctl.text.length,
      );
    });
    // Ensure focus on next frame
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _focus.requestFocus();
    });
  }

  void _cancel() {
    setState(() {
      _editing = false;
      _ctl.text = widget.title; // restore
    });
  }

  void _commit() {
    final raw = _ctl.text.trim();
    final next = raw.isEmpty ? widget.title : raw;
    if (next != widget.title) {
      widget.controller.renameBlueprint(widget.id, next);
    }
    setState(() => _editing = false);
  }

  @override
  Widget build(BuildContext context) {
    final isActive = widget.isActive;
    final bg =
        isActive ? const Color.fromARGB(255, 53, 52, 52) : const Color.fromARGB(255, 46, 45, 45);
    final fg =
        isActive ? const Color.fromARGB(255, 255, 169, 169) : const Color.fromARGB(255, 220, 220, 220);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 4),
      child: InkWell(
        onTap: () => widget.controller.activateBlueprint(widget.id),
        onDoubleTap: _startEdit,
        borderRadius: BorderRadius.circular(6),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          height: 22,
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(
              color: isActive
                  ? const Color.fromARGB(255, 255, 119, 230)
                  : const Color.fromARGB(60, 255, 119, 230),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (!_editing)
                Text(widget.title, style: TextStyle(fontSize: 11, color: fg))
              else
                SizedBox(
                  width: 140,
                  height: 18,
                  child: Shortcuts(
                    shortcuts: const <ShortcutActivator, Intent>{
                      SingleActivator(LogicalKeyboardKey.escape): DismissIntent(),
                    },
                    child: Actions(
                      actions: <Type, Action<Intent>>{
                        DismissIntent: CallbackAction<DismissIntent>(
                          onInvoke: (intent) {
                            _cancel();
                            return null;
                          },
                        ),
                      },
                      child: TextField(
                        focusNode: _focus,
                        controller: _ctl,
                        maxLines: 1,
                        onSubmitted: (_) => _commit(),
                        textAlignVertical: TextAlignVertical.center,
                        strutStyle: const StrutStyle(
                          height: 1.0,
                          leading: 0.0,
                          forceStrutHeight: true,
                        ),
                        style: const TextStyle(
                          fontSize: 11,
                          height: 1.2,
                          color: Colors.white,
                        ),
                        decoration: const InputDecoration(
                          isDense: true,
                          isCollapsed: true,
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: 4,
                            vertical: 1,
                          ),
                          border: OutlineInputBorder(
                            gapPadding: 0,
                            borderSide: BorderSide.none,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              const SizedBox(width: 6),
              GestureDetector(
                onTap: () => widget.controller.closeBlueprint(widget.id),
                child: const Icon(
                  Icons.close,
                  size: 14,
                  color: Color.fromARGB(200, 255, 119, 230),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
