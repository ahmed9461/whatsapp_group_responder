import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/models.dart';

class UsageAnalyticsCard extends StatefulWidget {
  const UsageAnalyticsCard({
    super.key,
    required this.statistics,
    required this.selectedPeriod,
    required this.loading,
    required this.onPeriodChanged,
  });

  final ApiStatistics statistics;
  final String selectedPeriod;
  final bool loading;
  final Future<void> Function(String period) onPeriodChanged;

  @override
  State<UsageAnalyticsCard> createState() => _UsageAnalyticsCardState();
}

class _UsageAnalyticsCardState extends State<UsageAnalyticsCard> {
  int? _selectedIndex;

  @override
  void didUpdateWidget(covariant UsageAnalyticsCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selectedPeriod != widget.selectedPeriod ||
        oldWidget.statistics.buckets.length != widget.statistics.buckets.length) {
      _selectedIndex = null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final stats = widget.statistics;
    final topCommand = stats.top.isEmpty ? null : stats.top.first;
    final topGroup = stats.topGroups.isEmpty ? null : stats.topGroups.first;
    final averageText = stats.averagePerBucket == 0
        ? '0'
        : stats.averagePerBucket < 10
            ? stats.averagePerBucket.toStringAsFixed(1)
            : stats.averagePerBucket.round().toString();
    final selected = _selectedIndex != null &&
            _selectedIndex! >= 0 &&
            _selectedIndex! < stats.buckets.length
        ? stats.buckets[_selectedIndex!]
        : null;

    return Card(
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(
                    Icons.insights_rounded,
                    color: theme.colorScheme.onPrimaryContainer,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'نشاط الردود',
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'بيانات فعلية من استخدام الردود داخل المجموعات',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                if (widget.loading)
                  const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(strokeWidth: 2.4),
                  ),
              ],
            ),
            const SizedBox(height: 18),
            SegmentedButton<String>(
              showSelectedIcon: false,
              segments: const [
                ButtonSegment(value: '24h', label: Text('24 ساعة')),
                ButtonSegment(value: '7d', label: Text('أسبوع')),
                ButtonSegment(value: '30d', label: Text('شهر')),
              ],
              selected: {widget.selectedPeriod},
              onSelectionChanged: widget.loading
                  ? null
                  : (value) => widget.onPeriodChanged(value.first),
            ),
            const SizedBox(height: 18),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '${stats.total}',
                  style: theme.textTheme.displaySmall?.copyWith(
                    fontWeight: FontWeight.w800,
                    height: 1,
                  ),
                ),
                const SizedBox(width: 8),
                Padding(
                  padding: const EdgeInsets.only(bottom: 3),
                  child: Text(
                    'استخدام خلال ${stats.periodLabel}',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.fromLTRB(10, 14, 10, 8),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest
                    .withValues(alpha: 0.42),
                borderRadius: BorderRadius.circular(18),
              ),
              child: Column(
                children: [
                  if (stats.buckets.isEmpty)
                    const SizedBox(
                      height: 180,
                      child: Center(
                        child: Text('لا توجد بيانات زمنية متاحة بعد'),
                      ),
                    )
                  else ...[
                    SizedBox(
                      height: 180,
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          return GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onTapDown: (details) => _selectAt(
                              details.localPosition.dx,
                              constraints.maxWidth,
                              stats.buckets.length,
                            ),
                            onHorizontalDragUpdate: (details) => _selectAt(
                              details.localPosition.dx,
                              constraints.maxWidth,
                              stats.buckets.length,
                            ),
                            child: CustomPaint(
                              painter: _UsageChartPainter(
                                buckets: stats.buckets,
                                selectedIndex: _selectedIndex,
                                lineColor: theme.colorScheme.primary,
                                gridColor: theme.colorScheme.outlineVariant,
                                fillColor: theme.colorScheme.primaryContainer,
                              ),
                              child: const SizedBox.expand(),
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 6),
                    _AxisLabels(
                      buckets: stats.buckets,
                      period: stats.period,
                    ),
                  ],
                ],
              ),
            ),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 180),
              child: selected == null
                  ? const SizedBox(height: 10)
                  : Padding(
                      key: ValueKey(selected.startAt),
                      padding: const EdgeInsets.only(top: 10),
                      child: Row(
                        children: [
                          Icon(
                            Icons.touch_app_rounded,
                            size: 18,
                            color: theme.colorScheme.primary,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _selectedLabel(selected, stats.period),
                              style: theme.textTheme.bodyMedium,
                            ),
                          ),
                          Text(
                            '${selected.uses} استخدام',
                            style: theme.textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: _MiniMetric(
                    icon: Icons.groups_2_outlined,
                    value: '${stats.activeGroups}',
                    label: 'مجموعات نشطة',
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _MiniMetric(
                    icon: Icons.speed_rounded,
                    value: averageText,
                    label: stats.period == '24h' ? 'متوسط/ساعة' : 'متوسط/يوم',
                  ),
                ),
              ],
            ),
            if (topCommand != null || topGroup != null) ...[
              const SizedBox(height: 10),
              Row(
                children: [
                  if (topCommand != null)
                    Expanded(
                      child: _Highlight(
                        icon: Icons.bolt_rounded,
                        title: 'الأكثر استخدامًا',
                        value: topCommand.title.isEmpty ? 'رد' : topCommand.title,
                        count: topCommand.uses,
                      ),
                    ),
                  if (topCommand != null && topGroup != null)
                    const SizedBox(width: 10),
                  if (topGroup != null)
                    Expanded(
                      child: _Highlight(
                        icon: Icons.group_work_outlined,
                        title: 'أنشط مجموعة',
                        value: topGroup.name,
                        count: topGroup.uses,
                      ),
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _selectAt(double dx, double width, int count) {
    if (count <= 0 || width <= 0) return;
    final normalized = (dx / width).clamp(0.0, 0.999999);
    final index = (normalized * count).floor();
    if (_selectedIndex != index) setState(() => _selectedIndex = index);
  }
}

class _MiniMetric extends StatelessWidget {
  const _MiniMetric({
    required this.icon,
    required this.value,
    required this.label,
  });

  final IconData icon;
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        border: Border.all(color: theme.colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Icon(icon, size: 21, color: theme.colorScheme.primary),
          const SizedBox(width: 9),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Highlight extends StatelessWidget {
  const _Highlight({
    required this.icon,
    required this.title,
    required this.value,
    required this.count,
  });

  final IconData icon;
  final String title;
  final String value;
  final int count;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: theme.colorScheme.secondaryContainer.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: theme.colorScheme.secondary),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.labelMedium,
                ),
              ),
            ],
          ),
          const SizedBox(height: 7),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 2),
          Text('$count استخدام', style: theme.textTheme.bodySmall),
        ],
      ),
    );
  }
}

class _AxisLabels extends StatelessWidget {
  const _AxisLabels({required this.buckets, required this.period});
  final List<ApiUsageBucket> buckets;
  final String period;

  @override
  Widget build(BuildContext context) {
    if (buckets.isEmpty) return const SizedBox.shrink();
    final middle = buckets[buckets.length ~/ 2];
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(_shortLabel(buckets.first.startAt, period)),
        Text(_shortLabel(middle.startAt, period)),
        Text(_shortLabel(buckets.last.startAt, period)),
      ],
    );
  }
}

class _UsageChartPainter extends CustomPainter {
  _UsageChartPainter({
    required this.buckets,
    required this.selectedIndex,
    required this.lineColor,
    required this.gridColor,
    required this.fillColor,
  });

  final List<ApiUsageBucket> buckets;
  final int? selectedIndex;
  final Color lineColor;
  final Color gridColor;
  final Color fillColor;

  @override
  void paint(Canvas canvas, Size size) {
    if (buckets.isEmpty || size.width <= 0 || size.height <= 0) return;

    const left = 4.0;
    const right = 4.0;
    const top = 8.0;
    const bottom = 8.0;
    final width = size.width - left - right;
    final height = size.height - top - bottom;

    final gridPaint = Paint()
      ..color = gridColor.withValues(alpha: 0.48)
      ..strokeWidth = 1;
    for (var i = 0; i <= 3; i++) {
      final y = top + height * i / 3;
      canvas.drawLine(Offset(left, y), Offset(size.width - right, y), gridPaint);
    }

    final maxUses = math.max(1, buckets.map((item) => item.uses).reduce(math.max));
    final points = <Offset>[];
    for (var i = 0; i < buckets.length; i++) {
      final x = buckets.length == 1
          ? left + width / 2
          : left + width * i / (buckets.length - 1);
      final ratio = buckets[i].uses / maxUses;
      final y = top + height * (1 - ratio);
      points.add(Offset(x, y));
    }

    final line = Path()..moveTo(points.first.dx, points.first.dy);
    if (points.length == 1) {
      line.lineTo(points.first.dx + 0.1, points.first.dy);
    } else {
      for (var i = 1; i < points.length; i++) {
        final previous = points[i - 1];
        final point = points[i];
        final midX = (previous.dx + point.dx) / 2;
        line.cubicTo(midX, previous.dy, midX, point.dy, point.dx, point.dy);
      }
    }

    final fill = Path.from(line)
      ..lineTo(points.last.dx, top + height)
      ..lineTo(points.first.dx, top + height)
      ..close();
    final fillPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          fillColor.withValues(alpha: 0.65),
          fillColor.withValues(alpha: 0.04),
        ],
      ).createShader(Rect.fromLTWH(left, top, width, height));
    canvas.drawPath(fill, fillPaint);

    canvas.drawPath(
      line,
      Paint()
        ..color = lineColor
        ..strokeWidth = 3
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..style = PaintingStyle.stroke,
    );

    if (selectedIndex != null &&
        selectedIndex! >= 0 &&
        selectedIndex! < points.length) {
      final point = points[selectedIndex!];
      canvas.drawLine(
        Offset(point.dx, top),
        Offset(point.dx, top + height),
        Paint()
          ..color = lineColor.withValues(alpha: 0.28)
          ..strokeWidth = 1.5,
      );
      canvas.drawCircle(
        point,
        7,
        Paint()..color = lineColor.withValues(alpha: 0.2),
      );
      canvas.drawCircle(point, 4, Paint()..color = lineColor);
    }
  }

  @override
  bool shouldRepaint(covariant _UsageChartPainter oldDelegate) {
    return oldDelegate.buckets != buckets ||
        oldDelegate.selectedIndex != selectedIndex ||
        oldDelegate.lineColor != lineColor ||
        oldDelegate.gridColor != gridColor ||
        oldDelegate.fillColor != fillColor;
  }
}

String _shortLabel(int milliseconds, String period) {
  final date = DateTime.fromMillisecondsSinceEpoch(milliseconds);
  if (period == '24h') {
    return '${_two(date.hour)}:${_two(date.minute)}';
  }
  return '${date.day}/${date.month}';
}

String _selectedLabel(ApiUsageBucket bucket, String period) {
  final start = DateTime.fromMillisecondsSinceEpoch(bucket.startAt);
  if (period == '24h') {
    return '${_two(start.hour)}:${_two(start.minute)} — ${start.day}/${start.month}';
  }
  return '${start.day}/${start.month}/${start.year}';
}

String _two(int value) => value.toString().padLeft(2, '0');
