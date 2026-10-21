import 'dart:convert';
import 'dart:io';

import 'mqtt_settings.dart';

class SensorReading {
  const SensorReading({required this.temperature, required this.humidity, required this.recordedAt});
  final double temperature, humidity;
  final String recordedAt;

  factory SensorReading.fromJson(Map<String, dynamic> json) => SensorReading(
    temperature: (json['temperature'] as num).toDouble(),
    humidity: (json['humidity'] as num).toDouble(),
    recordedAt: json['recorded_at'] as String,
  );
}

class HouseApi {
  const HouseApi(this._settings);
  final MqttSettings _settings;

  Future<List<SensorReading>> sensorHistory({int limit = 48}) async {
    final client = HttpClient();
    try {
      final request = await client.getUrl(Uri.parse('http://${_settings.host}:8000/dht11/readings?limit=$limit'));
      final response = await request.close().timeout(const Duration(seconds: 4));
      if (response.statusCode != HttpStatus.ok) return [];
      final decoded = jsonDecode(await response.transform(utf8.decoder).join());
      return decoded is List
          ? decoded.whereType<Map<String, dynamic>>().map(SensorReading.fromJson).toList()
          : [];
    } catch (_) {
      return [];
    } finally {
      client.close(force: true);
    }
  }
}
