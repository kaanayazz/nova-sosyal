import 'package:flutter/material.dart';

class NovaSafeBottom extends StatelessWidget {
  final Widget child;
  final double extraBottom;
  final EdgeInsetsGeometry? padding;

  const NovaSafeBottom({
    super.key,
    required this.child,
    this.extraBottom = 12,
    this.padding,
  });

  @override
  Widget build(BuildContext context) {
    final safeBottom = MediaQuery.of(context).viewPadding.bottom;

    return Padding(
      padding: (padding as EdgeInsets? ?? EdgeInsets.zero).copyWith(
        bottom: safeBottom + extraBottom,
      ),
      child: child,
    );
  }
}