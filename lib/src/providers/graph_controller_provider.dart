// lib/providers/graph_controller_provider.dart

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../controller/graph_controller.dart';

/// Expose the singleton GraphController.
final graphControllerProvider = Provider<GraphController>((_) {
  return GraphController();
});
