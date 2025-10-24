import 'package:flutter/material.dart';

import 'skeleton_box.dart';
import 'skeleton_card.dart';

/// Loading state widget displayed while dashboard data is being fetched
class LoadingState extends StatelessWidget {
  const LoadingState({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 720;
        final padding = EdgeInsets.symmetric(
          horizontal: compact ? 12 : 24,
          vertical: compact ? 16 : 32,
        );
        return Padding(
          padding: padding,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SkeletonBox(
                height: 28,
                width: 240,
                color: theme.colorScheme.surfaceContainerHighest,
              ),
              const SizedBox(height: 16),
              SkeletonBox(
                height: 18,
                width: 320,
                color: theme.colorScheme.surfaceContainerHighest,
              ),
              const SizedBox(height: 24),
              const Expanded(
                child: Column(
                  children: [
                    Expanded(child: SkeletonCard()),
                    SizedBox(height: 16),
                    Expanded(child: SkeletonCard()),
                    SizedBox(height: 16),
                    Expanded(child: SkeletonCard()),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
