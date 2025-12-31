// lib/src/controller/graph_controller.history.dart

part of 'graph_controller.core.dart';

// ───────────────── undo / redo stack (per tab) ─────────────────

mixin _HistoryMixin on _GraphCoreBase {
  bool get canUndo => _activeDoc?.history.canUndo ?? false;
  bool get canRedo => _activeDoc?.history.canRedo ?? false;

  void undo() {
    if (!canUndo) return;
    _restoreSnapshot(_activeDoc!.history.undo());
  }

  void redo() {
    if (!canRedo) return;
    _restoreSnapshot(_activeDoc!.history.redo());
  }
}
