// lib/src/widgets/toolbar/tab_chip.dart

part of '../toolbar.dart';

class _TabChip extends StatefulWidget {
  final String id;
  final String title;
  final bool isActive;
  final GraphController controller;

  const _TabChip({
    super.key,
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
  bool _pressed = false; // immediate visual feedback on pointer down
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
    // Clear pressed state once the real active chip updates.
    if (widget.isActive && _pressed) {
      setState(() => _pressed = false);
    }
    // Also clear if this chip just became inactive.
    if (!widget.isActive && oldWidget.isActive && _pressed) {
      setState(() => _pressed = false);
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

  // Release "pressed" on the next frame to avoid blink on fast taps.
  void _releasePress() {
    if (!mounted) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) setState(() => _pressed = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    // Use immediate visual pressed feedback OR real active state.
    final isActiveVisual = widget.isActive || _pressed;

    final bg = isActiveVisual
        ? const Color.fromARGB(255, 53, 52, 52)
        : const Color.fromARGB(255, 46, 45, 45);
    final fg = isActiveVisual
        ? const Color.fromARGB(255, 255, 169, 169)
        : const Color.fromARGB(255, 220, 220, 220);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 4),
      // Use MouseRegion to clear "pressed" when pointer exits; Listener for down/up/cancel.
      child: MouseRegion(
        onExit: (_) => _releasePress(),
        child: Listener(
          onPointerDown: (_) => setState(() => _pressed = true),
          onPointerUp: (_) => _releasePress(),
          onPointerCancel: (_) => _releasePress(),
          child: InkWell(
            onTapDown: (d) {
              // Arm probe and activate immediately.
              PerfSwitchProbe.start(widget.id);
              widget.controller.activateBlueprint(widget.id);
            },
            onTap: () {}, // no-op (we use onTapDown for immediacy)
            splashFactory: NoSplash.splashFactory,
            enableFeedback: false,
            splashColor: Colors.transparent,
            highlightColor: Colors.transparent,
            hoverColor: Colors.transparent,
            focusColor: Colors.transparent,
            borderRadius: BorderRadius.circular(6),
            // NOTE: removed onDoubleTap to eliminate gesture disambiguation delay.
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              height: 22,
              decoration: BoxDecoration(
                color: bg,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                  color: isActiveVisual
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
                          SingleActivator(LogicalKeyboardKey.escape):
                              DismissIntent(),
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
                  // NEW: explicit edit icon to enter rename mode (replaces double-tap).
                  GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTapDown: (_) {
                      // prevent triggering tab switch from this tap
                    },
                    onTap: _startEdit,
                    child: const Icon(
                      Icons.edit,
                      size: 14,
                      color: Color.fromARGB(200, 255, 119, 230),
                    ),
                  ),
                  const SizedBox(width: 6),
                  GestureDetector(
                    onTap: () {
                      // If the active tab is being closed, switch to the last created remaining tab.
                      final wasActive =
                          widget.controller.activeBlueprintId == widget.id;

                      // Compute fallback BEFORE closing (last item in current order that isn't this one).
                      final tabs = widget.controller.tabs;
                      String? fallback;
                      for (int i = tabs.length - 1; i >= 0; i--) {
                        final t = tabs[i];
                        if (t.id != widget.id) {
                          fallback = t.id;
                          break;
                        }
                      }

                      widget.controller.closeBlueprint(widget.id);

                      if (wasActive && fallback != null) {
                        // Explicitly activate the last-created surviving tab.
                        widget.controller.activateBlueprint(fallback);
                      }
                    },
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
        ),
      ),
    );
  }
}
