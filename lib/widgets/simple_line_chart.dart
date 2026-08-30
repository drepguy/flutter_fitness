import 'dart:math';
import 'package:flutter/material.dart';

class SimpleLineChart extends StatefulWidget {
  final List<double> data;
  final List<String> labels;

  const SimpleLineChart({super.key, required this.data, required this.labels});

  @override
  State<SimpleLineChart> createState() => _SimpleLineChartState();
}

class _SimpleLineChartState extends State<SimpleLineChart> {
  int? _selectedIndex;

  static const double _chartLeft = 24.0;
  static const double _chartRight = 16.0;
  static const double _chartTop = 8.0;
  static const double _chartBottom = 40.0;

  int _hitTest(Offset tap, double w, double h) {
    final chartW = w - _chartLeft - _chartRight;
    final data = widget.data;
    if (data.isEmpty) return -1;

    int closest = 0;
    double closestDist = double.infinity;
    for (int i = 0; i < data.length; i++) {
      final x = _chartLeft + (chartW * i / max(data.length - 1, 1));
      final dist = (tap.dx - x).abs();
      if (dist < closestDist) {
        closestDist = dist;
        closest = i;
      }
    }
    if (closestDist > 40) return -1;
    return closest;
  }

  @override
  Widget build(BuildContext context) {
    if (widget.data.isEmpty) return const SizedBox();

    final minVal = widget.data.reduce((a, b) => a < b ? a : b);
    final maxVal = widget.data.reduce((a, b) => a > b ? a : b);
    final range = maxVal - minVal;
    final padding = range > 0 ? range * 0.1 : 1.0;
    final yMin = minVal - padding;
    final yMax = maxVal + padding;

    return LayoutBuilder(
      builder: (context, constraints) {
        final w = constraints.maxWidth;
        final h = constraints.maxHeight;
        final chartH = h - _chartTop - _chartBottom;

        return GestureDetector(
          onTapDown: (details) {
            final idx = _hitTest(details.localPosition, w, h);
            setState(() => _selectedIndex = idx >= 0 ? idx : null);
          },
          onDoubleTap: () => setState(() => _selectedIndex = null),
          child: CustomPaint(
            size: Size(w, h),
            painter: _LineChartPainter(
              data: widget.data,
              labels: widget.labels,
              yMin: yMin,
              yMax: yMax,
              chartLeft: _chartLeft,
              chartTop: _chartTop,
              chartW: w - _chartLeft - _chartRight,
              chartH: chartH,
              selectedIndex: _selectedIndex,
            ),
          ),
        );
      },
    );
  }
}

class _LineChartPainter extends CustomPainter {
  final List<double> data;
  final List<String> labels;
  final double yMin, yMax;
  final double chartLeft, chartTop, chartW, chartH;
  final int? selectedIndex;

  _LineChartPainter({
    required this.data,
    required this.labels,
    required this.yMin,
    required this.yMax,
    required this.chartLeft,
    required this.chartTop,
    required this.chartW,
    required this.chartH,
    this.selectedIndex,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final linePaint = Paint()
      ..color = const Color(0xFFBB86FC)
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final dotPaint = Paint()
      ..color = const Color(0xFFBB86FC)
      ..style = PaintingStyle.fill;

    final gridPaint = Paint()
      ..color = const Color(0xFF2A2A32)
      ..strokeWidth = 1;

    final textPainter = TextPainter(textDirection: TextDirection.ltr);

    // Grid lines + Y labels
    for (int i = 0; i <= 4; i++) {
      final y = chartTop + chartH - (chartH * i / 4);
      canvas.drawLine(
        Offset(chartLeft, y),
        Offset(chartLeft + chartW, y),
        gridPaint,
      );
      final val = yMin + (yMax - yMin) * i / 4;
      textPainter.text = TextSpan(
        text: val.toStringAsFixed(0),
        style: const TextStyle(color: Color(0xFF8A8A8E), fontSize: 11),
      );
      textPainter.layout();
      textPainter.paint(
          canvas, Offset(chartLeft - textPainter.width - 6, y - 6));
    }

    if (data.length == 1) {
      final x = chartLeft + chartW / 2;
      final yNorm = (data[0] - yMin) / (yMax - yMin);
      final y = chartTop + chartH - (chartH * yNorm);
      canvas.drawCircle(Offset(x, y), 6, dotPaint);
      _drawTooltip(canvas, textPainter, Offset(x, y), labels[0], data[0]);
      return;
    }

    // Data points
    final points = <Offset>[];
    for (int i = 0; i < data.length; i++) {
      final x = chartLeft + (chartW * i / (data.length - 1));
      final yNorm = (data[i] - yMin) / (yMax - yMin);
      final y = chartTop + chartH - (chartH * yNorm);
      points.add(Offset(x, y));
    }

    // Line
    final path = Path();
    path.moveTo(points[0].dx, points[0].dy);
    for (int i = 1; i < points.length; i++) {
      path.lineTo(points[i].dx, points[i].dy);
    }
    canvas.drawPath(path, linePaint);

    // Gradient fill under line
    final fillPath = Path.from(path);
    fillPath.lineTo(points.last.dx, chartTop + chartH);
    fillPath.lineTo(points.first.dx, chartTop + chartH);
    fillPath.close();
    final fillPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          const Color(0xFFBB86FC).withValues(alpha: 0.25),
          const Color(0xFFBB86FC).withValues(alpha: 0.0),
        ],
      ).createShader(Rect.fromLTWH(chartLeft, chartTop, chartW, chartH));
    canvas.drawPath(fillPath, fillPaint);

    // Dots
    for (int i = 0; i < points.length; i++) {
      final isSelected = i == selectedIndex;
      canvas.drawCircle(points[i], isSelected ? 8 : 5, dotPaint);
    }

    // X labels (every Nth)
    final step = (data.length / 6).ceil().clamp(1, data.length);
    for (int i = 0; i < data.length; i += step) {
      final x = chartLeft + (chartW * i / (data.length - 1));
      canvas.save();
      canvas.translate(x, chartTop + chartH + 8);
      canvas.rotate(-1.5708); // -90 degrees
      textPainter.text = TextSpan(
        text: labels[i],
        style: const TextStyle(color: Color(0xFF8A8A8E), fontSize: 10),
      );
      textPainter.layout();
      textPainter.paint(canvas, Offset.zero);
      canvas.restore();
    }

    // Selected point highlight
    if (selectedIndex != null && selectedIndex! < points.length) {
      final p = points[selectedIndex!];

      // Vertical dashed line
      final dashPaint = Paint()
        ..color = const Color(0xFFBB86FC).withValues(alpha: 0.4)
        ..strokeWidth = 1;
      final dashTop = chartTop;
      final dashBottom = chartTop + chartH;
      for (double y = dashTop; y < dashBottom; y += 6) {
        canvas.drawLine(Offset(p.dx, y), Offset(p.dx, min(y + 3, dashBottom)), dashPaint);
      }

      // Tooltip
      _drawTooltip(canvas, textPainter, p, labels[selectedIndex!], data[selectedIndex!]);
    }
  }

  void _drawTooltip(Canvas canvas, TextPainter textPainter, Offset point, String label, double value) {
    final valueStr = value.toStringAsFixed(1);
    final tooltipText = '$label  $valueStr';
    textPainter.text = TextSpan(
      text: tooltipText,
      style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
    );
    textPainter.layout();

    final tooltipW = textPainter.width + 14;
    final tooltipH = textPainter.height + 10;
    var tooltipX = point.dx - tooltipW / 2;
    final tooltipY = point.dy - tooltipH - 14;

    // Keep tooltip within chart bounds
    if (tooltipX < chartLeft) tooltipX = chartLeft;
    if (tooltipX + tooltipW > chartLeft + chartW) tooltipX = chartLeft + chartW - tooltipW;

    final tooltipRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(tooltipX, tooltipY, tooltipW, tooltipH),
      const Radius.circular(6),
    );
    canvas.drawRRect(tooltipRect, Paint()..color = const Color(0xFF28282F));
    canvas.drawRRect(tooltipRect, Paint()
      ..color = const Color(0xFFBB86FC).withValues(alpha: 0.5)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1);

    textPainter.paint(canvas, Offset(tooltipX + 7, tooltipY + 5));
  }

  @override
  bool shouldRepaint(covariant _LineChartPainter oldDelegate) {
    return oldDelegate.data != data ||
        oldDelegate.labels != labels ||
        oldDelegate.selectedIndex != selectedIndex;
  }
}
