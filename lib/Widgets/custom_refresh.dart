import 'package:doc_delete/utils/session_manager.dart';
import 'package:flutter/material.dart';

class CustomRefresh extends StatelessWidget {
  final Future<void> Function() onRefresh;
  final Widget child;

  const CustomRefresh({
    super.key,
    required this.onRefresh,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: onRefresh,
      backgroundColor: Colors.white,
      color: AppColors.darkGreen,
      strokeWidth: 2.5,
      displacement: 40,
      child: child,
    );
  }
}
