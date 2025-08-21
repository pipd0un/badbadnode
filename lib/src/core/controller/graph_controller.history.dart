// lib/src/controller/graph_controller.history.dart

part of 'graph_controller.core.dart';

// ───────────────── undo / redo stack (per tab) ─────────────────

mixin _HistoryMixin on _GraphCoreBase {
  bool get canUndo => _doc.history.canUndo;
  bool get canRedo => _doc.history.canRedo;

  void undo() {
    if (!canUndo) return;
    _restoreSnapshot(_doc.history.undo());
  }

  void redo() {
    if (!canRedo) return;
    _restoreSnapshot(_doc.history.redo());
  }
}
