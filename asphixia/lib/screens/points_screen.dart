import 'package:flutter/material.dart';

import '../models/clan.dart';
import '../models/game_event.dart';
import '../models/player_profile.dart';
import '../models/user_notification.dart';
import '../services/game_state_service.dart';

class PointsScreen extends StatelessWidget {
  const PointsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<PlayerProfile?>(
      valueListenable: GameStateService.currentUser,
      builder: (context, profile, _) {
        final points = profile?.points ?? 0;

        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: const Color(0xFF162033),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.white12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Tus puntos',
                    style: TextStyle(color: Colors.white70),
                  ),
                  Text(
                    '$points',
                    style: const TextStyle(
                      fontSize: 42,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    profile?.name ?? 'Jugador',
                    style: const TextStyle(color: Colors.white70),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Guerra de clanes',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            ValueListenableBuilder<List<GameEvent>>(
              valueListenable: GameStateService.events,
              builder: (context, events, _) {
                final activeEvents = events
                    .where(
                      (event) =>
                          event.type == GameEventType.clanWar &&
                          event.isRunning,
                    )
                    .toList();
                final runningEvents =
                    events.where((event) => event.isRunning).toList()
                      ..sort((a, b) => a.endsAt.compareTo(b.endsAt));
                final event = activeEvents.isEmpty ? null : activeEvents.first;
                return ValueListenableBuilder<List<Clan>>(
                  valueListenable: GameStateService.clans,
                  builder: (context, clans, _) {
                    final ranked = [...clans]
                      ..sort((a, b) => b.eventPoints.compareTo(a.eventPoints));
                    final leaders = ranked.take(5).toList();
                    return Card(
                      color: const Color(0xFF1A222E),
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(event?.name ?? 'Sin evento activo'),
                            const SizedBox(height: 4),
                            Text(
                              event == null
                                  ? 'El admin puede iniciar una guerra desde el panel oculto.'
                                  : '${event.bonusPoints} pts extra | ${event.duration.inHours} h',
                              style: const TextStyle(color: Colors.white70),
                            ),
                            const Divider(),
                            if (runningEvents.isNotEmpty) ...[
                              Text(
                                'Eventos activos',
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                              const SizedBox(height: 4),
                              for (final running in runningEvents)
                                ListTile(
                                  contentPadding: EdgeInsets.zero,
                                  leading: Icon(
                                    running.type == GameEventType.clanWar
                                        ? Icons.sports_martial_arts
                                        : Icons.event,
                                  ),
                                  title: Text(running.name),
                                  subtitle: Text(running.type.label),
                                  trailing: Text('+${running.bonusPoints}'),
                                ),
                              const Divider(),
                            ],
                            for (var i = 0; i < leaders.length; i++)
                              ListTile(
                                contentPadding: EdgeInsets.zero,
                                leading: CircleAvatar(child: Text('#${i + 1}')),
                                title: Text(leaders[i].name),
                                trailing: Text('${leaders[i].eventPoints} pts'),
                              ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
            const SizedBox(height: 16),
            Text('Mensajes', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            ValueListenableBuilder<List<UserNotification>>(
              valueListenable: GameStateService.notifications,
              builder: (context, notifications, _) {
                if (notifications.isEmpty) {
                  return const Text('No tienes mensajes pendientes.');
                }

                return Column(
                  children: [
                    for (final notification in notifications)
                      Card(
                        color: const Color(0xFF1A222E),
                        child: ListTile(
                          leading: const Icon(Icons.mark_email_unread),
                          title: Text(notification.title),
                          subtitle: Text(notification.message),
                        ),
                      ),
                  ],
                );
              },
            ),
          ],
        );
      },
    );
  }
}
