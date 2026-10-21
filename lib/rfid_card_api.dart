import 'dart:convert';
import 'dart:io';

import 'mqtt_settings.dart';

class RfidCard {
  const RfidCard({
    required this.uid,
    required this.memberId,
    required this.memberName,
    this.lastSeenAt,
  });

  final String uid, memberId, memberName;
  final String? lastSeenAt;

  factory RfidCard.fromJson(Map<String, dynamic> json) => RfidCard(
    uid: json['uid'] as String,
    memberId: json['member_id'] as String,
    memberName: json['member_name'] as String,
    lastSeenAt: json['last_seen_at'] as String?,
  );
}

class RfidCardApi {
  const RfidCardApi(this._settings);
  final MqttSettings _settings;

  Future<List<RfidCard>> listCards() async {
    final client = HttpClient();
    try {
      final request = await client.getUrl(Uri.parse('http://${_settings.host}:8000/rfid/cards'));
      final response = await request.close().timeout(const Duration(seconds: 4));
      if (response.statusCode != HttpStatus.ok) return [];
      final body = await response.transform(utf8.decoder).join();
      final value = jsonDecode(body);
      if (value is! List) return [];
      return value.whereType<Map<String, dynamic>>().map(RfidCard.fromJson).toList();
    } catch (_) {
      return [];
    } finally {
      client.close(force: true);
    }
  }

  Future<List<RfidAccessLog>> accessLogs({int limit = 100}) async {
    final client = HttpClient();
    try {
      final request = await client.getUrl(Uri.parse('http://${_settings.host}:8000/rfid/access-logs?limit=$limit'));
      final response = await request.close().timeout(const Duration(seconds: 4));
      if (response.statusCode != HttpStatus.ok) return [];
      final value = jsonDecode(await response.transform(utf8.decoder).join());
      if (value is! List) return [];
      return value.whereType<Map<String, dynamic>>().map(RfidAccessLog.fromJson).toList();
    } catch (_) {
      return [];
    } finally {
      client.close(force: true);
    }
  }
}

class RfidAccessLog {
  const RfidAccessLog({required this.uid, required this.memberName, required this.granted, required this.scannedAt});
  final String uid;
  final String? memberName;
  final bool granted;
  final String scannedAt;

  factory RfidAccessLog.fromJson(Map<String, dynamic> json) => RfidAccessLog(
    uid: json['uid'] as String? ?? '',
    memberName: json['member_name'] as String?,
    granted: (json['granted'] as num?)?.toInt() == 1 || json['granted'] == true,
    scannedAt: json['scanned_at'] as String? ?? '',
  );
}
