// lib/src/widgets/toolbar/paste_json_dialog.dart

part of '../toolbar.dart';

/// Web-only helper dialog for pasting JSON.
/// Returns the pasted text, or null if cancelled.
Future<String?> showPasteJsonDialog(BuildContext context) async {
  final controller = TextEditingController();
  return showDialog<String>(
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
}
