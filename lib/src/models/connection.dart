// lib/models/connection.dart

/// A graph‐level connection between two port IDs.
class Connection {
  final String id;
  final String fromPortId;
  final String toPortId;
  Connection({
    required this.id,
    required this.fromPortId,
    required this.toPortId,
  });
}