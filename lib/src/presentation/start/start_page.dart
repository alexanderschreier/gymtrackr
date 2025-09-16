import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

class StartPage extends ConsumerWidget {
  const StartPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Start', style: Theme.of(context).textTheme.headlineMedium),
          const SizedBox(height: 8),
          const Text('Hier kommt dein Startbereich.'),
        ],
      ),
    );
  }
}
