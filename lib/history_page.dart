import 'package:flutter/material.dart';

import 'house_api.dart';
import 'mqtt_settings.dart';

class HistoryPage extends StatefulWidget {
  const HistoryPage({super.key, required this.settings});
  final MqttSettings settings;

  @override
  State<HistoryPage> createState() => _HistoryPageState();
}

class _HistoryPageState extends State<HistoryPage> {
  List<SensorReading>? _readings;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    final readings = await HouseApi(widget.settings).sensorHistory();
    if (mounted) setState(() => _readings = readings);
  }

  @override
  Widget build(BuildContext context) {
    final readings = _readings;
    return Scaffold(
      appBar: AppBar(title: const Text('環境紀錄')),
      body: readings == null
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _refresh,
              child: readings.isEmpty
                  ? ListView(
                      children: const [
                        SizedBox(height: 220),
                        Icon(Icons.sensors_off_outlined, size: 52, color: Color(0xFF5F6F7D)),
                        SizedBox(height: 16),
                        Center(child: Text('尚無溫濕度資料')),
                        SizedBox(height: 8),
                        Center(child: Text('確認 Pi 的 DHT11 服務與 FastAPI 已啟動。')),
                      ],
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.all(20),
                      itemCount: readings.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 10),
                      itemBuilder: (context, index) {
                        final reading = readings[index];
                        return Card(
                          child: ListTile(
                            leading: const Icon(Icons.thermostat_rounded, color: Color(0xFFC62828)),
                            title: Text('${reading.temperature.toStringAsFixed(1)}°C  ·  ${reading.humidity.toStringAsFixed(0)}%'),
                            subtitle: Text(reading.recordedAt),
                            trailing: const Icon(Icons.water_drop_outlined, color: Color(0xFF0077B6)),
                          ),
                        );
                      },
                    ),
            ),
    );
  }
}
