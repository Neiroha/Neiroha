import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:q_vox_lab/providers/app_providers.dart';

/// Compact server status indicator for the bottom of the sidebar or top bar.
class ServerStatusBar extends ConsumerWidget {
  const ServerStatusBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final running = ref.watch(serverRunningProvider);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      color: const Color(0xFF12121A),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: running ? Colors.green : Colors.orange,
              boxShadow: [
                if (running)
                  const BoxShadow(
                    color: Colors.green,
                    blurRadius: 6,
                  ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            running ? 'API :${ref.read(apiServerProvider).port}' : 'API Off',
            style: TextStyle(
              fontSize: 12,
              color: Colors.white.withValues(alpha: 0.6),
            ),
          ),
          const Spacer(),
          SizedBox(
            height: 24,
            child: Switch(
              value: running,
              onChanged: (value) async {
                final server = ref.read(apiServerProvider);
                if (value) {
                  await server.start();
                } else {
                  await server.stop();
                }
                ref.read(serverRunningProvider.notifier).state = value;
              },
            ),
          ),
        ],
      ),
    );
  }
}
