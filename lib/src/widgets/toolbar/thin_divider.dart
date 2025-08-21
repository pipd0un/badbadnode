// lib/src/widgets/toolbar/thin_divider.dart

part of '../toolbar.dart';

class _ThinDivider extends StatelessWidget {
  const _ThinDivider();

  @override
  Widget build(BuildContext context) {
    return const VerticalDivider(
      color: Color.fromARGB(255, 255, 90, 90),
      thickness: 1,
      width: 8,
      indent: 6,
      endIndent: 6,
    );
  }
}
