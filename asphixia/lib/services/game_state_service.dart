import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../models/clan.dart';
import '../models/clan_message.dart';
import '../models/game_event.dart';
import '../models/player_profile.dart';
import '../models/reward.dart';
import '../models/reward_redemption.dart';
import '../models/user_notification.dart';
import '../models/validation_photo.dart';
import '../models/zone_model.dart';
import 'api_service.dart';
import 'realtime_service.dart';

class GameStateService {
  GameStateService._();

  static Timer? _syncTimer;
  static final Map<ValueNotifier<dynamic>, dynamic> _pendingValues = {};
  static bool _publishScheduled = false;
  static final ValueNotifier<String?> lastError = ValueNotifier<String?>(null);

  static final ValueNotifier<List<Clan>> clans = ValueNotifier<List<Clan>>([]);
  static final ValueNotifier<List<PlayerProfile>> users =
      ValueNotifier<List<PlayerProfile>>([]);

  static final ValueNotifier<List<Zone>> zones = ValueNotifier<List<Zone>>([]);
  static final ValueNotifier<List<GameEvent>> events =
      ValueNotifier<List<GameEvent>>([]);
  static final ValueNotifier<List<ValidationPhoto>> validationPhotos =
      ValueNotifier<List<ValidationPhoto>>([]);
  static final ValueNotifier<PlayerProfile?> currentUser =
      ValueNotifier<PlayerProfile?>(null);
  static final ValueNotifier<List<RewardRedemption>> redemptions =
      ValueNotifier<List<RewardRedemption>>([]);
  static final ValueNotifier<List<UserNotification>> notifications =
      ValueNotifier<List<UserNotification>>([]);
  static final ValueNotifier<List<Reward>> rewards =
      ValueNotifier<List<Reward>>([
        const Reward(
          id: '1',
          name: 'Insignia verde',
          description: 'Marca tu perfil como jugador ecologico.',
          cost: 250,
        ),
        const Reward(
          id: '2',
          name: 'Boost x2 por 1h',
          description: 'Duplica tus puntos durante la proxima actividad.',
          cost: 500,
        ),
        const Reward(
          id: '3',
          name: 'Marco de clan',
          description: 'Personalizacion visual para tu clan.',
          cost: 850,
        ),
      ]);

  static void _publish<T>(ValueNotifier<T> notifier, T value) {
    _pendingValues[notifier] = value;
    if (_publishScheduled) return;

    _publishScheduled = true;
    Timer.run(() {
      _publishScheduled = false;
      final pending = Map<ValueNotifier<dynamic>, dynamic>.of(_pendingValues);
      _pendingValues.clear();

      for (final entry in pending.entries) {
        entry.key.value = entry.value;
      }
    });
  }

  static void _syncOnline(Future<void> request) {
    lastError.value = null;
    request.catchError((error) {
      lastError.value = error.toString();
      // Keep the optimistic local state when the dev backend is offline.
    });
  }

  static String get currentUserId {
    return FirebaseAuth.instance.currentUser?.uid ?? 'local-user';
  }

  static String get currentUserName {
    final user = FirebaseAuth.instance.currentUser;
    return user?.displayName ?? user?.email ?? 'Jugador';
  }

  static PlayerProfile get currentProfile {
    final authUser = FirebaseAuth.instance.currentUser;
    final id = authUser?.uid ?? 'local-user';
    return users.value.firstWhere(
      (user) => user.id == id,
      orElse: () => PlayerProfile(
        id: id,
        name: authUser?.displayName ?? authUser?.email ?? 'Jugador',
        email: authUser?.email ?? '',
      ),
    );
  }

  static void syncCurrentUser() {
    final authUser = FirebaseAuth.instance.currentUser;
    final profile = PlayerProfile(
      id: authUser?.uid ?? 'local-user',
      name: authUser?.displayName ?? authUser?.email ?? 'Jugador',
      email: authUser?.email ?? '',
      points: currentProfile.points,
      clanId: currentProfile.clanId,
      role: currentProfile.role,
    );
    _upsertUser(profile);
    _syncOnline(ApiService.saveUser(profile));
  }

  static bool get currentUserHasClan {
    return clans.value.any(
      (clan) =>
          clan.ownerId == currentUserId ||
          clan.memberIds.contains(currentUserId),
    );
  }

  static void resetSession() {
    _publish(currentUser, null);
    _publish(notifications, <UserNotification>[]);
  }

  static void startOnlineSync() {
    _syncTimer?.cancel();
    RealtimeService.connect(
      onStateChanged: refreshOnline,
      onChatChanged: () {},
    );
    refreshOnline();
    _syncTimer = Timer.periodic(
      const Duration(seconds: 3),
      (_) => refreshOnline(),
    );
  }

  static Future<void> refreshOnline() async {
    try {
      final remoteClans = await ApiService.fetchClans();
      final remoteUsers = await ApiService.fetchUsers();
      final remoteZones = await ApiService.fetchZones();
      final remoteEvents = await ApiService.fetchEvents();
      final remoteRewards = await ApiService.fetchRewards();
      final remotePhotos = await ApiService.fetchPhotos();
      final remoteRedemptions = await ApiService.fetchRedemptions();
      final remoteNotifications = await ApiService.fetchNotifications(
        currentUserId,
      );

      _publish(clans, remoteClans);
      _publish(users, remoteUsers);
      final profileIndex = remoteUsers.indexWhere(
        (user) => user.id == currentUserId,
      );
      if (profileIndex != -1) {
        _publish(currentUser, remoteUsers[profileIndex]);
      } else {
        _publish(currentUser, currentProfile);
      }
      _publish(zones, remoteZones);
      _publish(events, remoteEvents);
      if (remoteRewards.isNotEmpty) _publish(rewards, remoteRewards);
      _publish(validationPhotos, remotePhotos);
      _publish(redemptions, remoteRedemptions);
      _publish(notifications, remoteNotifications);
    } catch (_) {
      // Offline fallback: keep local state.
    }
  }

  static void saveClan(Clan clan) {
    lastError.value = null;
    final isNewClan = !clans.value.any((item) => item.id == clan.id);
    if (isNewClan && currentUserHasClan) {
      lastError.value = 'Ya perteneces a un clan.';
      return;
    }

    final items = [...clans.value];
    final index = items.indexWhere((item) => item.id == clan.id);
    if (index == -1) {
      items.add(clan);
    } else {
      items[index] = clan;
    }
    _publish(clans, items);
    if (clan.memberIds.contains(currentUserId)) {
      _upsertUser(currentProfile.copyWith(clanId: clan.id));
    }
    _syncOnline(ApiService.saveClan(clan));
  }

  static void joinClan(String clanId) {
    lastError.value = null;
    if (currentUserHasClan) {
      lastError.value = 'No puedes unirte a otro clan.';
      return;
    }
    final clan = clans.value.firstWhere((item) => item.id == clanId);
    if (clan.memberIds.contains(currentUserId)) return;
    saveClan(
      clan.copyWith(
        memberIds: [...clan.memberIds, currentUserId],
        pendingMemberIds: clan.pendingMemberIds
            .where((id) => id != currentUserId)
            .toList(),
      ),
    );
  }

  static void requestClanJoin(String clanId) {
    lastError.value = null;
    if (currentUserHasClan) {
      lastError.value = 'No puedes solicitar otro clan.';
      return;
    }
    final clan = clans.value.firstWhere((item) => item.id == clanId);
    if (clan.memberIds.contains(currentUserId)) return;
    if (clan.pendingMemberIds.contains(currentUserId)) return;
    saveClan(
      clan.copyWith(
        pendingMemberIds: [...clan.pendingMemberIds, currentUserId],
      ),
    );
  }

  static void approveClanJoin(String clanId, String userId) {
    final clan = clans.value.firstWhere((item) => item.id == clanId);
    saveClan(
      clan.copyWith(
        memberIds: {...clan.memberIds, userId}.toList(),
        pendingMemberIds: clan.pendingMemberIds
            .where((id) => id != userId)
            .toList(),
      ),
    );
  }

  static void addClanPoints(String clanId, int points) {
    _publish(clans, [
      for (final clan in clans.value)
        if (clan.id == clanId)
          clan.copyWith(eventPoints: clan.eventPoints + points)
        else
          clan,
    ]);
  }

  static void clearClans() {
    _publish(clans, []);
    _syncOnline(ApiService.clearClans());
  }

  static void _upsertUser(PlayerProfile profile) {
    final items = [...users.value];
    final index = items.indexWhere((item) => item.id == profile.id);
    if (index == -1) {
      items.add(profile);
    } else {
      items[index] = profile;
    }
    _publish(users, items);
    if (profile.id == currentUserId) {
      _publish(currentUser, profile);
    }
  }

  static void addPlayerPoints(
    int points, {
    String? userId,
    String reason = 'Puntos manuales',
  }) {
    final id = userId ?? currentUserId;
    final profile = users.value.firstWhere(
      (user) => user.id == id,
      orElse: () => PlayerProfile(
        id: id,
        name: id == currentUserId ? currentUserName : 'Jugador',
        email: FirebaseAuth.instance.currentUser?.email ?? '',
      ),
    );
    final updated = profile.copyWith(points: profile.points + points);
    _upsertUser(updated);
    _syncOnline(
      ApiService.addUserPoints(userId: id, points: points, reason: reason),
    );
  }

  static bool claimReward(String rewardId) {
    final reward = rewards.value.firstWhere((item) => item.id == rewardId);
    if (currentProfile.points < reward.cost) return false;

    addPlayerPoints(-reward.cost, reason: 'Recompensa: ${reward.name}');
    final redemption = RewardRedemption(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      rewardId: reward.id,
      rewardName: reward.name,
      userId: currentUserId,
      userName: currentUserName,
      cost: reward.cost,
      createdAt: DateTime.now(),
    );
    _publish(redemptions, [redemption, ...redemptions.value]);
    _syncOnline(ApiService.saveRedemption(redemption));
    return true;
  }

  static void updateRedemption(
    RewardRedemption redemption, {
    required RedemptionStatus status,
    required String adminMessage,
  }) {
    final updated = redemption.copyWith(
      status: status,
      adminMessage: adminMessage,
    );
    _publish(redemptions, [
      for (final item in redemptions.value)
        if (item.id == updated.id) updated else item,
    ]);
    _syncOnline(ApiService.updateRedemption(updated));
  }

  static void saveReward(Reward reward) {
    final items = [...rewards.value];
    final index = items.indexWhere((item) => item.id == reward.id);
    if (index == -1) {
      items.add(reward);
    } else {
      items[index] = reward;
    }
    _publish(rewards, items);
    _syncOnline(ApiService.saveReward(reward));
  }

  static void deleteReward(String rewardId) {
    _publish(
      rewards,
      rewards.value.where((reward) => reward.id != rewardId).toList(),
    );
    _syncOnline(ApiService.deleteReward(rewardId));
  }

  static void saveZone(Zone zone) {
    final items = [...zones.value];
    final index = items.indexWhere((item) => item.id == zone.id);
    if (index == -1) {
      items.add(zone);
    } else {
      items[index] = zone;
    }
    _publish(zones, items);
    _syncOnline(ApiService.saveZone(zone));
  }

  static void deleteZone(String zoneId) {
    _publish(zones, zones.value.where((zone) => zone.id != zoneId).toList());
    _syncOnline(ApiService.deleteZone(zoneId));
  }

  static void saveEvent(GameEvent event) {
    final items = [...events.value];
    final index = items.indexWhere((item) => item.id == event.id);
    if (index == -1) {
      items.add(event);
    } else {
      items[index] = event;
    }
    _publish(events, items);
    _syncOnline(ApiService.saveEvent(event));
  }

  static void deleteEvent(String eventId) {
    _publish(
      events,
      events.value.where((event) => event.id != eventId).toList(),
    );
    _syncOnline(ApiService.deleteEvent(eventId));
  }

  static void submitValidationPhoto(ValidationPhoto photo) {
    _publish(validationPhotos, [photo, ...validationPhotos.value]);
    _syncOnline(ApiService.savePhoto(photo));
  }

  static void updateValidationStatus(
    String photoId,
    ValidationStatus status, {
    int awardedPoints = 0,
  }) {
    final updatedPhotos = [
      for (final photo in validationPhotos.value)
        if (photo.id == photoId)
          photo.copyWith(status: status, awardedPoints: awardedPoints)
        else
          photo,
    ];
    _publish(validationPhotos, updatedPhotos);

    final updated = updatedPhotos.firstWhere((photo) => photo.id == photoId);
    if (status == ValidationStatus.approved && awardedPoints > 0) {
      final profile = users.value.firstWhere(
        (user) => user.id == updated.userId,
        orElse: () => PlayerProfile(
          id: updated.userId,
          name: updated.userName,
          email: '',
        ),
      );
      _upsertUser(profile.copyWith(points: profile.points + awardedPoints));
    }
    _syncOnline(ApiService.updatePhoto(updated));
  }

  static Future<List<ClanMessage>> fetchClanMessages(String clanId) {
    return ApiService.fetchClanMessages(clanId);
  }

  static Future<List<ClanMessage>> fetchGlobalMessages() {
    return ApiService.fetchGlobalMessages();
  }

  static void sendClanMessage({required String clanId, required String text}) {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return;

    _syncOnline(
      ApiService.sendClanMessage(
        ClanMessage(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          clanId: clanId,
          userId: currentUserId,
          userName: currentUserName,
          text: trimmed,
          createdAt: DateTime.now(),
        ),
      ),
    );
  }

  static void sendGlobalMessage({required String text}) {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return;

    _syncOnline(
      ApiService.sendGlobalMessage(
        ClanMessage(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          clanId: 'global',
          userId: currentUserId,
          userName: currentUserName,
          text: trimmed,
          createdAt: DateTime.now(),
        ),
      ),
    );
  }

  static void claimZone(Zone zone, {required double speedMetersPerSecond}) {
    final updated = zone.copyWith(
      ownerId: currentUserId,
      ownerName: currentUserName,
      state: ZoneState.claimed,
      laps: zone.laps + 1,
      bestSpeedMetersPerSecond: speedMetersPerSecond,
    );
    _publish(zones, [
      for (final item in zones.value)
        if (item.id == zone.id) updated else item,
    ]);
    _syncOnline(
      ApiService.challengeZone(
        zoneId: zone.id,
        userId: currentUserId,
        userName: currentUserName,
        clanId: currentProfile.clanId,
        speedMetersPerSecond: speedMetersPerSecond,
        laps: updated.laps,
      ),
    );
    final profile = currentProfile;
    _upsertUser(profile.copyWith(points: profile.points + 10));

    final clanId = currentProfile.clanId;
    if (clanId.isEmpty) return;
    _publish(clans, [
      for (final clan in clans.value)
        if (clan.id == clanId)
          clan.copyWith(eventPoints: clan.eventPoints + 10)
        else
          clan,
    ]);
  }
}
