import 'package:doc_delete/utils/session_manager.dart';
import 'package:flutter/material.dart';

class SectionWidget extends StatelessWidget {
  final IconData? icon;
  final String? title;
  final Widget child;
  final Widget? trailing;

  const SectionWidget({
    super.key,
    this.icon,
    this.title,
    required this.child,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,

      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10),
        ],
      ),

      padding: const EdgeInsets.all(18),

      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: AppColors.darkGreen),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title ?? "",
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                    color: Colors.black87,
                  ),
                ),
              ),
              if (trailing != null) trailing!,
            ],
          ),

          const SizedBox(height: 15),

          child,
        ],
      ),
    );
  }
}
