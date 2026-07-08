import 'package:socket_io_client/socket_io_client.dart' as io;

import 'api_service.dart';

class RealtimeService {
  RealtimeService._();

  static io.Socket? _socket;

  static void connect({
    required void Function() onStateChanged,
    required void Function() onChatChanged,
  }) {
    if (_socket?.connected == true) return;

    _socket = io.io(
      ApiService.baseUrl.replaceFirst(RegExp(r'/api$'), ''),
      io.OptionBuilder()
          .setTransports(['websocket'])
          .enableAutoConnect()
          .enableReconnection()
          .build(),
    );

    for (final eventName in [
      'users:updated',
      'clans:updated',
      'zones:updated',
      'events:updated',
      'rewards:updated',
      'redemptions:updated',
      'photos:updated',
      'leaderboard:updated',
      'map:updated',
    ]) {
      _socket!.on(eventName, (_) => onStateChanged());
    }

    _socket!.on('chat:message', (_) => onChatChanged());
    _socket!.on('chat:global', (_) => onChatChanged());
  }

  static void joinClan(String clanId) {
    _socket?.emit('join:clan', clanId);
  }

  static void leaveClan(String clanId) {
    _socket?.emit('leave:clan', clanId);
  }

  static void disconnect() {
    _socket?.dispose();
    _socket = null;
  }
}
