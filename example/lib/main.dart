import 'package:badbad/node.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'util/web_stub.dart'
    if (dart.library.html) 'package:web/web.dart'
    as web;
import 'util/register.dart' show registerCustomNodes;

void main() {
  registerCustomNodes();
  if (kIsWeb) {
    web.window.document.body?.onContextMenu.listen(
      (event) => event.preventDefault(),
    );
  }

  runApp(const ProviderScope(child: NodeEditorApp()));
}

class NodeEditorApp extends ConsumerWidget {
  const NodeEditorApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final messengerKey = ref.watch(scaffoldMessengerKeyProvider);
    SnackbarService.messengerKey ??= messengerKey;

    return MaterialApp(
      title: 'badbad/node',
      scaffoldMessengerKey: messengerKey,
      theme: ThemeData(primarySwatch: Colors.blue),
      home: const NodeEditorHome(),
    );
  }
}

class NodeEditorHome extends ConsumerWidget {
  const NodeEditorHome({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      backgroundColor: Colors.black87,
      appBar: const Toolbar(),
      body: Host(),
    );
  }
}
