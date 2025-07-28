# Bad Bad Node — Node Editor for HerIndexOfErrors

**bad bad node** is a procedural, extensible, and high-performance node-based visual editor built with Flutter. Designed for use cases such as ... .
Runs smoothly in the browser and supports full user interaction with real-time execution, drag-and-drop wiring, undo/redo, and plugin-based node registration.

> **🎯 Live Demo:** _Coming soon_

---

## ✨ Features

- 🔌 **Plugin API**: Define custom nodes with just a few lines of code.
- ⚙️ **Pure Dart evaluation engine**: No Flutter dependency at runtime.
- 💾 **JSON I/O**: Clipboard & file-based import/export.
- 🖱️ **Marquee selection**, drag, snap-to-grid.
- 🧠 **Built-in nodes**: Numbers, Strings, Lists, Operators, Control Flow.
- 🧩 **Custom UI**: Each node can define its own widget layout.
- 🎨 **Virtualized canvas**: Fast performance with hundreds of nodes.
- 🧱 **Undo/Redo**: Built-in time-travel graph state.
- 🌐 **Flutter Web**: 100% client-side. No backend required.

---

## 🚀 Getting Started

To run the editor:

```bash
fvm flutter pub get
fvm flutter run -d chrome
```

---

## 🧩 Writing Your Own Node

Creating a new node is simple. Just extend `SimpleNode` and implement the logic:

```dart
// lib/custom_node/factorial_node.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:badbad/node.dart';

class FactorialNode extends SimpleNode {
  @override
  String get type => 'Factorial';

  @override
  List<String> get inputs => const ['in'];

  @override
  List<String> get outputs => const ['out'];

  @override
  Map<String, dynamic> get initialData => {
    'inputs': inputs,
    'outputs': outputs,
  };

  @override
  Future run(Node node, GraphEvaluator eval) async {
    final n = (eval.input(node, 'in') ?? 0) as num;
    int f(int k) => k < 2 ? 1 : k * f(k - 1);
    return f(n.toInt());
  }

  @override
  Widget buildWidget(Node node, WidgetRef ref) =>
      GenericNodeWidget(node: node);
}
```

Then register your node during app startup:

```dart
// lib/util/register.dart
import 'package:badbad/node.dart' show registerNode;
import '../nodes/custom/factorial_node.dart';

void registerCustomNodes() {
  registerNode(FactorialNode());
}
```

---

## 📂 Folder Structure

```
├── lib/
│   ├── controller/       # Graph controller + clipboard, undo, JSON
│   ├── core/             # Events, message hub, Graph Evaluator
│   ├── domain/           # Graph model + immutable mutations
│   ├── models/           # Node, Connection
│   ├── nodes/            # Built-in and custom nodes
│   ├── painter/          # Canvas layers (grid, wires, selection, preview)
│   ├── providers/        # Riverpod providers for UI and state
│   ├── services/         # Asset and history services
│   └── widgets/          # UI components and layered canvas
├── test/                 # Performance and widget tests
├── tool/                 # Version bump tool
└── pubspec.yaml
```

---

## 🧪 Tests

### Performance Test (500 Nodes)

```bash
fvm flutter test test/performance_500_nodes_test.dart
```

Ensures the canvas maintains ≥30fps while panning with 500 nodes.

---

## 📦 Built-in Nodes

|    Type    |              Description                |
|------------|-----------------------------------------|
| `number`   | Constant number value                   |
| `string`   | Constant text value                     |
| `list`     | Combine multiple inputs into list       |
| `operator` | Add / Subtract / Multiply / Divide      |
| `comparator` | == / != / > / < / >= / <=             |
| `if`       | Conditional routing                     |
| `loop`     | Iterates list and expands subgraph      |
| `print`    | Logs to devtools + snackbar             |
| `sink`     | Dummy endpoint (Seems mostly as a joke) |

---

## 🧠 Architecture

- UI is built with Flutter and Riverpod.
- Core runtime (`GraphEvaluator`) is Flutter-independent and can be reused elsewhere.
- All graph changes are immutable and trigger `GraphChanged` events.

---

## 🛠️ Plugin API

You can register new node types at runtime using:

```dart
registerNode(MyCustomNode());
```

Each `NodeDefinition` includes:
- `type`: Unique string name.
- `inputs` / `outputs`: List of port names.
- `initialData`: Optional custom state.
- `run()`: Async Dart function.
- `buildWidget()`: Flutter widget inspector.

---

## 📃 License

ForgotToBeNamed License © 2025
