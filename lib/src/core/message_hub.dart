// lib/core/message_hub.dart

import 'dart:async';

/// A lightweight singleton for event broadcasting
/// Any object can be posted; listeners filter by type.
class MessageHub {
  MessageHub._internal();

  /// The single shared instance.
  static final MessageHub _singleton = MessageHub._internal();

  /// Factory constructor that always returns the same instance.
  factory MessageHub() => _singleton;

  /// Broadcast controller so multiple listeners can subscribe.
  final StreamController<dynamic> _controller =
      StreamController<dynamic>.broadcast();

  /// Listen for events of type [T].
  Stream<T> on<T>() => _controller.stream.where((e) => e is T).cast<T>();

  /// Post an event onto the bus.
  void fire(dynamic event) => _controller.add(event);

  /// Dispose the controller when the app shuts down (optional).
  void dispose() => _controller.close();
}