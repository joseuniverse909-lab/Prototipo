import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;

import '../models/clan.dart';
import '../models/clan_message.dart';
import '../models/game_event.dart';
import '../models/player_profile.dart';
import '../models/reward.dart';
import '../models/reward_redemption.dart';
import '../models/user_notification.dart';
import '../models/validation_photo.dart';
import '../models/zone_model.dart';

class ApiService {
  static const String baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://192.168.1.7:3001',
  );
  static const Map<String, String> _adminHeaders = {
    'X-Admin-Secret': 'dev-admin',
  };

  static Future<Map<String, String>> _headers([
    Map<String, String> extra = const {},
  ]) async {
    final token = await FirebaseAuth.instance.currentUser?.getIdToken();
    return {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
      ...extra,
    };
  }

  static Future<List<Clan>> fetchClans() async {
    final data = await _getList('/api/clans');
    return data.map((item) => Clan.fromJson(item)).toList();
  }

  static Future<List<PlayerProfile>> fetchUsers() async {
    final data = await _getList('/api/users');
    return data.map((item) => PlayerProfile.fromJson(item)).toList();
  }

  static Future<void> saveUser(PlayerProfile user) async {
    await _post('/api/users', {
      'id': user.id,
      'name': user.name,
      'email': user.email,
      'clanId': user.clanId,
    });
  }

  static Future<void> addUserPoints({
    required String userId,
    required int points,
    required String reason,
  }) async {
    await _post('/api/users/$userId/points', {
      'points': points,
      'reason': reason,
    });
  }

  static Future<List<RewardRedemption>> fetchRedemptions() async {
    final data = await _getList('/api/redemptions');
    return data.map((item) => RewardRedemption.fromJson(item)).toList();
  }

  static Future<void> saveRedemption(RewardRedemption redemption) async {
    await _post('/api/redemptions', redemption.toJson());
  }

  static Future<void> updateRedemption(RewardRedemption redemption) async {
    await _put('/api/redemptions', redemption.toJson(), headers: _adminHeaders);
  }

  static Future<List<UserNotification>> fetchNotifications(
    String userId,
  ) async {
    final data = await _getList('/api/users/$userId/notifications');
    return data.map((item) => UserNotification.fromJson(item)).toList();
  }

  static Future<List<ClanMessage>> fetchClanMessages(String clanId) async {
    final data = await _getList('/api/clans/$clanId/messages');
    return data.map((item) => ClanMessage.fromJson(item)).toList();
  }

  static Future<List<ClanMessage>> fetchGlobalMessages() async {
    final data = await _getList('/api/global/messages');
    return data.map((item) => ClanMessage.fromJson(item)).toList();
  }

  static Future<void> sendClanMessage(ClanMessage message) async {
    await _post('/api/clans/${message.clanId}/messages', message.toJson());
  }

  static Future<void> sendGlobalMessage(ClanMessage message) async {
    await _post('/api/global/messages', message.toJson());
  }

  static Future<void> saveClan(Clan clan) async {
    await _post('/api/clans', clan.toJson());
  }

  static Future<void> clearClans() async {
    await _delete('/api/clans');
  }

  static Future<List<Zone>> fetchZones() async {
    final data = await _getList('/api/zones');
    return data.map((item) => Zone.fromJson(item)).toList();
  }

  static Future<void> saveZone(Zone zone) async {
    await _post('/api/zones', zone.toJson());
  }

  static Future<void> deleteZone(String id) async {
    await _delete('/api/zones?id=$id');
  }

  static Future<void> challengeZone({
    required String zoneId,
    required String userId,
    required String userName,
    required String clanId,
    required double speedMetersPerSecond,
    required int laps,
  }) async {
    await _post('/api/zones/challenge', {
      'zoneId': zoneId,
      'userId': userId,
      'userName': userName,
      'clanId': clanId,
      'speedMetersPerSecond': speedMetersPerSecond,
      'laps': laps,
    });
  }

  static Future<List<GameEvent>> fetchEvents() async {
    final data = await _getList('/api/events');
    return data.map((item) => GameEvent.fromJson(item)).toList();
  }

  static Future<void> saveEvent(GameEvent event) async {
    await _post('/api/events', event.toJson(), headers: _adminHeaders);
  }

  static Future<void> deleteEvent(String id) async {
    await _delete('/api/events?id=$id', headers: _adminHeaders);
  }

  static Future<List<Reward>> fetchRewards() async {
    final data = await _getList('/api/rewards');
    return data.map((item) => Reward.fromJson(item)).toList();
  }

  static Future<void> saveReward(Reward reward) async {
    await _post('/api/rewards', reward.toJson(), headers: _adminHeaders);
  }

  static Future<void> deleteReward(String id) async {
    await _delete('/api/rewards?id=$id', headers: _adminHeaders);
  }

  static Future<List<ValidationPhoto>> fetchPhotos() async {
    final data = await _getList('/api/photos');
    return data.map((item) => ValidationPhoto.fromJson(item)).toList();
  }

  static Future<void> savePhoto(ValidationPhoto photo) async {
    await _post('/api/photos', photo.toJson());
  }

  static Future<void> updatePhoto(ValidationPhoto photo) async {
    await _post('/api/admin/photos/validate', {
      'photoId': photo.id,
      'status': photo.status.name,
      'awardedPoints': photo.awardedPoints,
    }, headers: _adminHeaders);
  }

  static Future<List<Map<String, dynamic>>> _getList(String path) async {
    final response = await http.get(
      Uri.parse('$baseUrl$path'),
      headers: await _headers(),
    );
    if (response.statusCode >= 400) {
      throw ApiException(response.statusCode, response.body);
    }
    final decoded = jsonDecode(response.body);
    if (decoded is! List) return [];
    return decoded.cast<Map<String, dynamic>>();
  }

  static Future<void> _post(
    String path,
    Map<String, dynamic> body, {
    Map<String, String> headers = const {},
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl$path'),
      headers: await _headers(headers),
      body: jsonEncode(body),
    );
    _throwIfFailed(response);
  }

  static Future<void> _put(
    String path,
    Map<String, dynamic> body, {
    Map<String, String> headers = const {},
  }) async {
    final response = await http.put(
      Uri.parse('$baseUrl$path'),
      headers: await _headers(headers),
      body: jsonEncode(body),
    );
    _throwIfFailed(response);
  }

  static Future<void> _delete(
    String path, {
    Map<String, String> headers = const {},
  }) async {
    final response = await http.delete(
      Uri.parse('$baseUrl$path'),
      headers: await _headers(headers),
    );
    _throwIfFailed(response);
  }

  static void _throwIfFailed(http.Response response) {
    if (response.statusCode < 400) return;
    throw ApiException(response.statusCode, response.body);
  }
}

class ApiException implements Exception {
  final int statusCode;
  final String body;

  const ApiException(this.statusCode, this.body);

  @override
  String toString() => 'ApiException($statusCode): $body';
}
