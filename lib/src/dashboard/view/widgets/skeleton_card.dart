import 'package:flutter/material.dart';

import 'skeleton_box.dart';

/// Skeleton card placeholder for loading chart states
class SkeletonCard extends StatelessWidget {
  const SkeletonCard({super.key});

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context)
        .colorScheme
        .surfaceContainerHighest
        .withValues(alpha: 0.5);
    return Container(
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          const SizedBox(height: 16),
          SkeletonBox(height: 20, width: 160, color: color),
          const SizedBox(height: 16),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Container(
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
