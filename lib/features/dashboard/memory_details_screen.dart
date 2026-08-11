import 'package:flutter/material.dart';

class MemoryDetailsScreen extends StatelessWidget {
  const MemoryDetailsScreen({super.key, required this.resources});

  final Map<String, dynamic> resources;

  @override
  Widget build(BuildContext context) {
    final memory = _memoryMap(resources);
    final total = _asDouble(memory['total']);
    final used = _asDouble(memory['used']);
    final available = total != null && used != null ? (total - used).clamp(0, total) : null;
    final percent = total != null && total > 0 && used != null
        ? ((used / total) * 100).clamp(0, 100).toDouble()
        : null;

    final totalLabel = _formattedMb(memory, 'total_frmt', total);
    final usedLabel = _formattedMb(memory, 'used_frmt', used);
    final availableLabel = _formatBytes(available);
    final arc = _asDouble(memory['arc']);
    final arcLabel = _formattedMb(memory, 'arc_frmt', arc);

    return Scaffold(
      appBar: AppBar(title: const Text('Memory')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: Theme.of(context)
                              .colorScheme
                              .primary
                              .withValues(alpha: .12),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          Icons.memory_outlined,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Memory usage',
                              style: Theme.of(context)
                                  .textTheme
                                  .titleLarge
                                  ?.copyWith(fontWeight: FontWeight.w800),
                            ),
                            Text(
                              percent == null
                                  ? 'Resource information'
                                  : '${percent.round()}% currently in use',
                              style: TextStyle(
                                color: Theme.of(context)
                                    .colorScheme
                                    .onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  if (percent != null) ...[
                    const SizedBox(height: 20),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(99),
                      child: LinearProgressIndicator(
                        value: percent / 100,
                        minHeight: 10,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          LayoutBuilder(
            builder: (context, constraints) {
              final columns = constraints.maxWidth >= 560 ? 3 : 2;
              final items = <Widget>[
                _MemoryStat(
                  label: 'Total',
                  value: totalLabel,
                  icon: Icons.storage_outlined,
                ),
                _MemoryStat(
                  label: 'Used',
                  value: usedLabel,
                  icon: Icons.donut_large_outlined,
                ),
                _MemoryStat(
                  label: 'Available',
                  value: availableLabel,
                  icon: Icons.check_circle_outline,
                ),
                if (arc != null || memory['arc_frmt'] != null)
                  _MemoryStat(
                    label: 'ZFS ARC',
                    value: arcLabel,
                    icon: Icons.layers_outlined,
                  ),
              ];
              return GridView.count(
                crossAxisCount: columns,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
                childAspectRatio: 1.45,
                children: items,
              );
            },
          ),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.info_outline,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Text(
                      'Memory values are calculated from the firewall system resource counters. ZFS ARC is shown separately when available.',
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MemoryStat extends StatelessWidget {
  const _MemoryStat({
    required this.label,
    required this.value,
    required this.icon,
  });

  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 22, color: Theme.of(context).colorScheme.primary),
            const SizedBox(height: 10),
            Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

Map<String, dynamic> _memoryMap(Map<String, dynamic> resources) {
  final value = resources['memory'];
  if (value is Map<String, dynamic>) return value;
  if (value is Map) return Map<String, dynamic>.from(value);
  return const <String, dynamic>{};
}

double? _asDouble(dynamic value) {
  if (value is num) return value.toDouble();
  if (value == null) return null;
  return double.tryParse(value.toString().trim());
}

String _formattedMb(
  Map<String, dynamic> memory,
  String formattedKey,
  double? bytes,
) {
  final formatted = memory[formattedKey]?.toString().trim();
  if (formatted != null && formatted.isNotEmpty) {
    return '$formatted MB';
  }
  return _formatBytes(bytes);
}

String _formatBytes(double? bytes) {
  if (bytes == null) return '—';
  const kb = 1024.0;
  const mb = kb * 1024;
  const gb = mb * 1024;
  if (bytes >= gb) return '${(bytes / gb).toStringAsFixed(1)} GB';
  if (bytes >= mb) return '${(bytes / mb).toStringAsFixed(0)} MB';
  if (bytes >= kb) return '${(bytes / kb).toStringAsFixed(0)} KB';
  return '${bytes.toStringAsFixed(0)} B';
}
