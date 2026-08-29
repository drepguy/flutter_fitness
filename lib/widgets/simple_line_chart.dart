import 'package:flutter/material.dart';

class SimpleLineChart extends StatelessWidget {
  final List<double> data;
  final List<String> labels;

  const SimpleLineChart({super.key, required this.data, required this.labels});

  @override
  Widget build(BuildContext context) {
    if (data.isEmpty) return const SizedBox();

    final minVal = data.reduce((a, b) => a < b ? a : b);
    final maxVal = data.reduce((a, b) => a > b ? a : b);
    final range = maxVal - minVal;
    final padding = range > 0 ? range * 0.1 : 1.0;
    final yMin = minVal - padding;
    final yMax = maxVal + padding;

    return LayoutBuilder(
      builder: (context, constraints) {
        final w = constraints.maxWidth;
        final h = constraints.maxHeight;
        final chartLeft = 50.0;
        final chartRight = 16.0;
        final chartTop = 8.0;
        final chartBottom = 40.0;
        final chartW = w - chartLeft - chartRight;
        final chartH = h - chartTop - chartBottom;

        return CustomPaint(
          size: Size(w, h),
          painter: _LineChartPainter(
            data: data,
            labels: labels,
            yMin: yMin,
            yMax: yMax,
            chartLeft: chartLeft,
            chartTop: chartTop,
            chartW: chartW,
            chartH: chartH,
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

  _LineChartPainter({
    required this.data,
    required this.labels,
    required this.yMin,
    required this.yMax,
    required this.chartLeft,
    required this.chartTop,
    required this.chartW,
    required this.chartH,
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

    // Dots
    for (final p in points) {
      canvas.drawCircle(p, 5, dotPaint);
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
  }

  @override
  bool shouldRepaint(covariant _LineChartPainter oldDelegate) {
    return oldDelegate.data != data || oldDelegate.labels != labels;
  }
}
