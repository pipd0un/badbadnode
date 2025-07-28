// example/lib/util/register.dart
import 'package:badbad/node.dart' show registerNode;
import '../custom_node/factorial_node.dart' show FactorialNode;

/// Call this before `runApp()`.  The mere *import* triggers registration.
void registerCustomNodes() {
  registerNode(FactorialNode());
}