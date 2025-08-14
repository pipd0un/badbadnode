// lib/src/widgets/viewport_bridge.dart

import 'dart:async';
import 'dart:developer' as dev;
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/ui/viewport_provider.dart';

/// Publishes the *screen* size (not the scene-space viewport).
/// I snap and only publish on real changes to avoid rebuild loops.
class ViewportBridge extends ConsumerStatefulWidget {
  const ViewportBridge({super.key, required this.child});
  final Widget child;

  @override
  ConsumerState<ViewportBridge> createState() => _ViewportBridgeState();
}

class _ViewportBridgeState extends ConsumerState<ViewportBridge> {
  Size? _last;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (_, constraints) {
        final raw = constraints.biggest;
        if (!raw.width.isFinite || !raw.height.isFinite || raw.isEmpty) {
          return widget.child;
        }

        // Snap to whole logical pixels to kill fractional jitter.
        final snapped = Size(
          raw.width.floorToDouble(),
          raw.height.floorToDouble(),
        );

        if (_last != snapped) {
          _last = snapped;
          scheduleMicrotask(() {
            final n = ref.read(screenSizeProvider.notifier);
            if (n.state != snapped) {
              n.state = snapped;
              dev.log(
                '[perf] ViewportBridge ${identityHashCode(this).toRadixString(16)} '
                'screen=${snapped.width.toInt()}x${snapped.height.toInt()}',
                name: 'badbadnode.perf',
              );
            }
          });
        }

        return widget.child;
      },
    );
  }
}
