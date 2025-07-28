// lib/models/node.dart

class Node {
  final String id;
  final String type;
  final Map<String, dynamic> data;

  Node({required this.id, required this.type, required this.data});

  factory Node.fromJson(Map<String, dynamic> json) {
    // Copy the raw data map
    final raw = Map<String, dynamic>.from(json['data'] as Map);

    // Normalize inputs/outputs to List<String>
    if (raw['inputs'] is List) {
      raw['inputs'] =
          (raw['inputs'] as List).map((e) => e.toString()).toList();
    }
    if (raw['outputs'] is List) {
      raw['outputs'] =
          (raw['outputs'] as List).map((e) => e.toString()).toList();
    }

    return Node(
      id: json['id'] as String,
      type: json['type'] as String,
      data: raw,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'type': type,
        'data': data,
      };
}
