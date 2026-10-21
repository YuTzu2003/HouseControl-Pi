import 'dart:async';

import 'package:flutter/material.dart';

import 'house_api.dart';
import 'mqtt_settings.dart';
import 'rfid_card_api.dart';

class HistoryPage extends StatefulWidget {
  const HistoryPage({super.key, required this.settings});
  final MqttSettings settings;
  @override
  State<HistoryPage> createState() => _HistoryPageState();
}

class _HistoryPageState extends State<HistoryPage> {
  List<SensorReading>? _readings;
  List<RfidAccessLog>? _accessLogs;
  Timer? _autoRefresh;
  bool _refreshing = false;

  @override
  void initState() {
    super.initState();
    _refresh();
    _autoRefresh = Timer.periodic(const Duration(seconds: 30), (_) => _refresh());
  }

  @override
  void dispose() {
    _autoRefresh?.cancel();
    super.dispose();
  }

  Future<void> _refresh() async {
    if (_refreshing) return;
    _refreshing = true;
    try {
      final results = await Future.wait([
        HouseApi(widget.settings).sensorHistory(limit: 48),
        RfidCardApi(widget.settings).accessLogs(limit: 100),
      ]);
      if (mounted) {
        setState(() {
          _readings = results[0] as List<SensorReading>;
          _accessLogs = results[1] as List<RfidAccessLog>;
        });
      }
    } finally {
      _refreshing = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final readings = _readings;
    final accessLogs = _accessLogs;
    return Scaffold(
      appBar: AppBar(
        title: const Text('紀錄'),
        actions: [IconButton(onPressed: _refresh, tooltip: '重新整理', icon: const Icon(Icons.refresh_rounded))],
      ),
      body: readings == null || accessLogs == null
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _refresh,
              child: ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  const _SectionTitle('環境趨勢'),
                  const SizedBox(height: 10),
                  _SensorHistoryCard(readings: readings),
                  const SizedBox(height: 24),
                  const _SectionTitle('出入紀錄'),
                  const SizedBox(height: 10),
                  if (accessLogs.isEmpty)
                    const Card(child: ListTile(title: Text('目前還沒有 RFID 感應紀錄')))
                  else
                    for (final log in accessLogs) _AccessLogCard(log: log),
                ],
              ),
            ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.title);
  final String title;
  @override
  Widget build(BuildContext context) => Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700));
}

class _SensorHistoryCard extends StatelessWidget {
  const _SensorHistoryCard({required this.readings});
  final List<SensorReading> readings;
  @override
  Widget build(BuildContext context) {
    final ordered = readings.reversed.toList();
    final latest = readings.isEmpty ? null : readings.first;
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            const Expanded(child: Text('溫濕度', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700))),
            if (latest != null) Text('${latest.temperature.toStringAsFixed(1)}°C · ${latest.humidity.toStringAsFixed(0)}%', style: const TextStyle(fontWeight: FontWeight.w600)),
          ]),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            height: 220,
            child: ordered.isEmpty
                ? const Center(child: Text('目前沒有溫濕度資料'))
                : LayoutBuilder(
                    builder: (context, constraints) => GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTapUp: (details) {
                        const chartLeft = 30.0;
                        const chartRight = 30.0;
                        final width = constraints.maxWidth - chartLeft - chartRight;
                        final position = (details.localPosition.dx - chartLeft).clamp(0.0, width);
                        final index = ordered.length == 1 ? 0 : ((position / width) * (ordered.length - 1)).round();
                        _showReadingDetails(context, ordered[index]);
                      },
                      child: CustomPaint(painter: _SensorChartPainter(ordered)),
                    ),
                  ),
          ),
          const SizedBox(height: 8),
          if (ordered.isNotEmpty)
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              Text(_formatReadingTime(ordered.first.recordedAt), style: const TextStyle(color: Color(0xFF5F6F7D), fontSize: 11)),
              Text(_formatReadingTime(ordered.last.recordedAt), style: const TextStyle(color: Color(0xFF5F6F7D), fontSize: 11)),
            ]),
          const SizedBox(height: 8),
          const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            _LegendDot(color: Color(0xFFC62828), label: '溫度 °C'),
            SizedBox(width: 20),
            _LegendDot(color: Color(0xFF0077B6), label: '濕度 %'),
          ]),
        ]),
      ),
    );
  }

  void _showReadingDetails(BuildContext context, SensorReading reading) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 4, 24, 28),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('讀值詳情', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
            const SizedBox(height: 6),
            Text(reading.recordedAt, style: const TextStyle(color: Color(0xFF5F6F7D))),
            const SizedBox(height: 20),
            Row(children: [
              const Icon(Icons.thermostat_rounded, color: Color(0xFFC62828)),
              const SizedBox(width: 10),
              const Text('溫度', style: TextStyle(color: Color(0xFF5F6F7D))),
              const Spacer(),
              Text('${reading.temperature.toStringAsFixed(1)}°C', style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w700)),
            ]),
            const SizedBox(height: 14),
            Row(children: [
              const Icon(Icons.water_drop_outlined, color: Color(0xFF0077B6)),
              const SizedBox(width: 10),
              const Text('濕度', style: TextStyle(color: Color(0xFF5F6F7D))),
              const Spacer(),
              Text('${reading.humidity.toStringAsFixed(0)}%', style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w700)),
            ]),
          ]),
        ),
      ),
    );
  }
}

String _formatReadingTime(String value) {
  final date = DateTime.tryParse(value)?.toLocal();
  if (date == null) return value;
  return '${date.month}/${date.day} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
}

class _LegendDot extends StatelessWidget {
  const _LegendDot({required this.color, required this.label});
  final Color color;
  final String label;
  @override
  Widget build(BuildContext context) => Row(children: [Container(width: 10, height: 10, decoration: BoxDecoration(color: color, shape: BoxShape.circle)), const SizedBox(width: 6), Text(label)]);
}

class _AccessLogCard extends StatelessWidget {
  const _AccessLogCard({required this.log});
  final RfidAccessLog log;
  @override
  Widget build(BuildContext context) {
    final color = log.granted ? const Color(0xFF3478F6) : const Color(0xFFC62828);
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        leading: Icon(log.granted ? Icons.verified_user_outlined : Icons.block_outlined, color: color),
        title: Text(log.memberName ?? '未綁定卡片'),
        subtitle: Text('${log.scannedAt}\nUID: ${log.uid}'),
        isThreeLine: true,
        trailing: Text(log.granted ? '允許' : '拒絕', style: TextStyle(color: color, fontWeight: FontWeight.w800)),
      ),
    );
  }
}

class _SensorChartPainter extends CustomPainter {
  _SensorChartPainter(this.readings);
  final List<SensorReading> readings;
  @override
  void paint(Canvas canvas, Size size) {
    const left = 30.0, top = 12.0, right = 30.0, bottom = 24.0;
    final chart = Rect.fromLTRB(left, top, size.width - right, size.height - bottom);
    final grid = Paint()..color = const Color(0xFFE4EAF0)..strokeWidth = 1;
    final tempPaint = Paint()..color = const Color(0xFFC62828)..style = PaintingStyle.stroke..strokeWidth = 2.5;
    final humidityPaint = Paint()..color = const Color(0xFF0077B6)..style = PaintingStyle.stroke..strokeWidth = 2.5;
    for (var i = 0; i <= 4; i++) {
      final y = chart.top + chart.height * i / 4;
      canvas.drawLine(Offset(chart.left, y), Offset(chart.right, y), grid);
      final temperatureLabel = TextPainter(text: TextSpan(text: '${40 - i * 10}', style: const TextStyle(fontSize: 10, color: Color(0xFFC62828))), textDirection: TextDirection.ltr)..layout();
      final humidityLabel = TextPainter(text: TextSpan(text: '${100 - i * 25}', style: const TextStyle(fontSize: 10, color: Color(0xFF0077B6))), textDirection: TextDirection.ltr)..layout();
      temperatureLabel.paint(canvas, Offset(0, y - 7));
      humidityLabel.paint(canvas, Offset(size.width - humidityLabel.width, y - 7));
    }
    Path line(double Function(SensorReading) value) {
      final path = Path();
      for (var i = 0; i < readings.length; i++) {
        final x = readings.length == 1 ? chart.center.dx : chart.left + chart.width * i / (readings.length - 1);
        final normalized = value(readings[i]).clamp(0, 100).toDouble();
        final y = chart.bottom - (normalized / 100) * chart.height;
        if (i == 0) path.moveTo(x, y); else path.lineTo(x, y);
      }
      return path;
    }
    canvas.drawPath(line((r) => r.temperature / .4), tempPaint);
    canvas.drawPath(line((r) => r.humidity), humidityPaint);
    for (var i = 0; i < readings.length; i++) {
      final x = readings.length == 1 ? chart.center.dx : chart.left + chart.width * i / (readings.length - 1);
      final tempY = chart.bottom - ((readings[i].temperature / .4).clamp(0, 100).toDouble() / 100) * chart.height;
      final humidityY = chart.bottom - (readings[i].humidity.clamp(0, 100).toDouble() / 100) * chart.height;
      canvas.drawCircle(Offset(x, tempY), 3, Paint()..color = tempPaint.color);
      canvas.drawCircle(Offset(x, humidityY), 3, Paint()..color = humidityPaint.color);
    }
  }
  @override
  bool shouldRepaint(covariant _SensorChartPainter oldDelegate) => oldDelegate.readings != readings;
}
