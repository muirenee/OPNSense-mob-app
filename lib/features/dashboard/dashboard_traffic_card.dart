import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/api/opnsense_api_client.dart';
import '../network/network_repository.dart';
import '../profiles/firewall_profile.dart';
import 'dashboard_models.dart';

class DashboardTrafficCard extends StatefulWidget {
  const DashboardTrafficCard({
    super.key,
    required this.profile,
    required this.credentials,
    required this.interfaces,
  });

  final FirewallProfile profile;
  final FirewallCredentials credentials;
  final List<InterfaceSummary> interfaces;

  @override
  State<DashboardTrafficCard> createState() => _DashboardTrafficCardState();
}

class _DashboardTrafficCardState extends State<DashboardTrafficCard>
    with WidgetsBindingObserver {
  late NetworkRepository _repository;
  Timer? _timer;
  DateTime? _previousAt;
  Map<String, Map<String, int?>>? _previous;
  Map<String, _TrafficRate> _rates = const {};
  final List<_TrafficPoint> _history = [];
  String? _selectedInterface;
  bool _polling = false;
  Object? _lastError;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _buildRepository();
    _startPolling();
  }

  @override
  void didUpdateWidget(covariant DashboardTrafficCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.profile.id != widget.profile.id) {
      _buildRepository();
      _previous = null;
      _previousAt = null;
      _rates = const {};
      _history.clear();
      _selectedInterface = null;
      _poll();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _startPolling();
    } else {
      _stopPolling();
    }
  }

  void _buildRepository() {
    _repository = NetworkRepository(
      OpnSenseApiClient(
        profile: widget.profile,
        credentials: widget.credentials,
      ),
    );
  }

  void _startPolling() {
    _timer?.cancel();
    _poll();
    _timer = Timer.periodic(const Duration(seconds: 2), (_) => _poll());
  }

  void _stopPolling() {
    _timer?.cancel();
    _timer = null;
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _stopPolling();
    super.dispose();
  }

  Future<void> _poll() async {
    if (_polling) return;
    _polling = true;
    try {
      if (widget.profile.isDemo) {
        _pollDemoTraffic();
        return;
      }

      final counters = await _repository.loadInterfaceCounters();
      final now = DateTime.now();
      final previous = _previous;
      final previousAt = _previousAt;
      final nextRates = <String, _TrafficRate>{};

      if (previous != null && previousAt != null) {
        final seconds = now.difference(previousAt).inMilliseconds / 1000.0;
        if (seconds > 0) {
          for (final entry in counters.entries) {
            final before = previous[entry.key];
            if (before == null) continue;
            nextRates[entry.key] = _TrafficRate(
              down: _rate(before['rxBytes'], entry.value['rxBytes'], seconds),
              up: _rate(before['txBytes'], entry.value['txBytes'], seconds),
            );
          }
        }
      }

      var selected = _selectedInterface;
      if (selected == null || !counters.containsKey(selected)) {
        selected = _defaultInterface(counters.keys);
      }
      final rate = selected == null ? null : nextRates[selected];

      if (!mounted) return;
      setState(() {
        _previous = counters;
        _previousAt = now;
        _rates = nextRates;
        _selectedInterface = selected;
        _lastError = null;
        if (rate != null) {
          _addHistory(rate);
        }
      });
    } catch (error) {
      if (mounted) setState(() => _lastError = error);
    } finally {
      _polling = false;
    }
  }

  void _pollDemoTraffic() {
    if (!mounted) return;

    final now = DateTime.now();
    final seconds = now.millisecondsSinceEpoch / 1000.0;

    // Keep Demo Mode visually alive without contacting any external service.
    // Values are representative current WAN usage, not a line-speed test.
    final down = math.max(
      0.0,
      9500000 +
          (4200000 * math.sin(seconds / 4.1)) +
          (1800000 * math.sin(seconds / 1.9 + 0.8)),
    );
    final up = math.max(
      0.0,
      1800000 +
          (720000 * math.sin(seconds / 5.3 + 1.2)) +
          (310000 * math.sin(seconds / 2.4)),
    );
    final rate = _TrafficRate(down: down, up: up);

    setState(() {
      _previous = const {
        'wan': {
          'rxBytes': 0,
          'txBytes': 0,
          'rxPackets': 0,
          'txPackets': 0,
        },
      };
      _previousAt = now;
      _rates = {'wan': rate};
      _selectedInterface = 'wan';
      _lastError = null;
      _addHistory(rate);
    });
  }

  void _addHistory(_TrafficRate rate) {
    _history.add(_TrafficPoint(rate.down, rate.up));
    if (_history.length > 30) _history.removeAt(0);
  }

  String? _defaultInterface(Iterable<String> keys) {
    final available = keys.toList();
    if (available.isEmpty) return null;
    for (final key in available) {
      if (key.toLowerCase() == 'wan') return key;
    }
    for (final interface in widget.interfaces) {
      if (available.contains(interface.identifier) &&
          interface.description.toLowerCase().contains('wan')) {
        return interface.identifier;
      }
    }
    for (final interface in widget.interfaces) {
      if (available.contains(interface.identifier)) return interface.identifier;
    }
    return available.first;
  }

  String _label(String id) {
    for (final interface in widget.interfaces) {
      if (interface.identifier == id) {
        return interface.description.isEmpty ? id : interface.description;
      }
    }
    return id;
  }

  void _select(String? value) {
    if (value == null || value == _selectedInterface) return;
    setState(() {
      _selectedInterface = value;
      _history.clear();
      final rate = _rates[value];
      if (rate != null) _addHistory(rate);
    });
  }

  static double _rate(int? before, int? after, double seconds) {
    if (before == null || after == null || after < before || seconds <= 0) {
      return 0;
    }
    return ((after - before) * 8) / seconds;
  }

  @override
  Widget build(BuildContext context) {
    final selected = _selectedInterface;
    final current = selected == null ? null : _rates[selected];
    final choices = _previous?.keys.toList() ?? const <String>[];
    final selectedLabel = selected == null ? 'WAN' : _label(selected);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: Theme.of(context)
                        .colorScheme
                        .primary
                        .withValues(alpha: .11),
                    borderRadius: BorderRadius.circular(11),
                  ),
                  child: Icon(
                    Icons.monitor_heart_outlined,
                    size: 20,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Live Internet Traffic',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.w800,
                            ),
                      ),
                      Text(
                        '$selectedLabel throughput · last 60 seconds',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                _LiveBadge(active: _lastError == null),
              ],
            ),
            if (choices.length > 1) ...[
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: selected,
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: 'Internet interface',
                  isDense: true,
                ),
                items: choices
                    .map(
                      (id) => DropdownMenuItem(
                        value: id,
                        child: Text('${_label(id)} · $id'),
                      ),
                    )
                    .toList(),
                onChanged: _select,
              ),
            ],
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: _TrafficMetric(
                    icon: Icons.arrow_downward,
                    label: 'Download',
                    value: _formatBitrate(current?.down ?? 0),
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _TrafficMetric(
                    icon: Icons.arrow_upward,
                    label: 'Upload',
                    value: _formatBitrate(current?.up ?? 0),
                    color: Theme.of(context).colorScheme.tertiary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            SizedBox(
              height: 150,
              width: double.infinity,
              child: _history.length < 2
                  ? Center(
                      child: Text(
                        _lastError == null
                            ? 'Collecting live traffic samples…'
                            : 'Live traffic temporarily unavailable.',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    )
                  : CustomPaint(
                      painter: _TrafficGraphPainter(
                        points: List<_TrafficPoint>.unmodifiable(_history),
                        downColor: Theme.of(context).colorScheme.primary,
                        upColor: Theme.of(context).colorScheme.tertiary,
                        gridColor: Theme.of(context)
                            .colorScheme
                            .outline
                            .withValues(alpha: .18),
                      ),
                    ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: Wrap(
                    spacing: 16,
                    runSpacing: 4,
                    children: [
                      _LegendDot(
                        label: 'Download',
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      _LegendDot(
                        label: 'Upload',
                        color: Theme.of(context).colorScheme.tertiary,
                      ),
                    ],
                  ),
                ),
                Text(
                  'Current usage',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _LiveBadge extends StatelessWidget {
  const _LiveBadge({required this.active});

  final bool active;

  @override
  Widget build(BuildContext context) {
    final color = active
        ? Colors.green
        : Theme.of(context).colorScheme.error;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .10),
        borderRadius: BorderRadius.circular(99),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 5),
          Text(
            active ? 'LIVE' : 'OFFLINE',
            style: TextStyle(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.w800,
              letterSpacing: .35,
            ),
          ),
        ],
      ),
    );
  }
}

class _TrafficMetric extends StatelessWidget {
  const _TrafficMetric({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .07),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: Theme.of(context).textTheme.bodySmall),
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _LegendDot extends StatelessWidget {
  const _LegendDot({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 5),
        Text(label, style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }
}

class _TrafficRate {
  const _TrafficRate({required this.down, required this.up});
  final double down;
  final double up;
}

class _TrafficPoint {
  const _TrafficPoint(this.down, this.up);
  final double down;
  final double up;
}

class _TrafficGraphPainter extends CustomPainter {
  const _TrafficGraphPainter({
    required this.points,
    required this.downColor,
    required this.upColor,
    required this.gridColor,
  });

  final List<_TrafficPoint> points;
  final Color downColor;
  final Color upColor;
  final Color gridColor;

  @override
  void paint(Canvas canvas, Size size) {
    final grid = Paint()
      ..color = gridColor
      ..strokeWidth = 1;
    for (var i = 1; i < 4; i++) {
      final y = size.height * i / 4;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), grid);
    }

    var maxValue = 1.0;
    for (final point in points) {
      if (point.down > maxValue) maxValue = point.down;
      if (point.up > maxValue) maxValue = point.up;
    }

    Path buildPath(double Function(_TrafficPoint) select) {
      final path = Path();
      final divisor = points.length <= 1 ? 1 : points.length - 1;
      for (var i = 0; i < points.length; i++) {
        final x = size.width * i / divisor;
        final normalized = (select(points[i]) / maxValue).clamp(0.0, 1.0);
        final y = size.height - (normalized * (size.height - 4)) - 2;
        if (i == 0) {
          path.moveTo(x, y);
        } else {
          path.lineTo(x, y);
        }
      }
      return path;
    }

    final downPaint = Paint()
      ..color = downColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.4
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final upPaint = Paint()
      ..color = upColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.4
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    canvas.drawPath(buildPath((point) => point.down), downPaint);
    canvas.drawPath(buildPath((point) => point.up), upPaint);
  }

  @override
  bool shouldRepaint(covariant _TrafficGraphPainter oldDelegate) {
    return oldDelegate.points != points ||
        oldDelegate.downColor != downColor ||
        oldDelegate.upColor != upColor ||
        oldDelegate.gridColor != gridColor;
  }
}

String _formatBitrate(double bitsPerSecond) {
  if (bitsPerSecond >= 1000000000) {
    return '${(bitsPerSecond / 1000000000).toStringAsFixed(1)} Gbps';
  }
  if (bitsPerSecond >= 1000000) {
    return '${(bitsPerSecond / 1000000).toStringAsFixed(1)} Mbps';
  }
  if (bitsPerSecond >= 1000) {
    return '${(bitsPerSecond / 1000).toStringAsFixed(1)} Kbps';
  }
  return '${bitsPerSecond.toStringAsFixed(0)} bps';
}
