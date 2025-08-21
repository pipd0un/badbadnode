// lib/providers/graph_controller_provider.dart

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/controller/graph_controller.core.dart';

/// Expose the singleton GraphController.
final graphControllerProvider = Provider<GraphController>((_) {
  return GraphController();
});
