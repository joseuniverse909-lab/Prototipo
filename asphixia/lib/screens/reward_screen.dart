import 'package:flutter/material.dart';

import '../models/player_profile.dart';
import '../models/reward.dart';
import '../models/reward_redemption.dart';
import '../services/game_state_service.dart';

class RewardScreen extends StatelessWidget {
  const RewardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<PlayerProfile?>(
      valueListenable: GameStateService.currentUser,
      builder: (context, profile, _) {
        final points = profile?.points ?? 0;
        return ValueListenableBuilder<List<Reward>>(
          valueListenable: GameStateService.rewards,
          builder: (context, rewards, _) {
            return ValueListenableBuilder<List<RewardRedemption>>(
              valueListenable: GameStateService.redemptions,
              builder: (context, redemptions, _) {
                final mine = redemptions
                    .where(
                      (item) => item.userId == GameStateService.currentUserId,
                    )
                    .toList();

                return ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    Text(
                      'Disponibles: $points pts',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 12),
                    for (final reward in rewards)
                      Card(
                        color: const Color(0xFF1A222E),
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const CircleAvatar(
                                backgroundColor: Colors.redAccent,
                                child: Icon(Icons.card_giftcard),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      reward.name,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      reward.description,
                                      style: const TextStyle(
                                        color: Colors.white70,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),
                              FilledButton(
                                onPressed: () {
                                  final ok = GameStateService.claimReward(
                                    reward.id,
                                  );
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        ok
                                            ? 'Canje enviado al admin'
                                            : 'No tienes puntos suficientes',
                                      ),
                                    ),
                                  );
                                },
                                child: Text('${reward.cost} pts'),
                              ),
                            ],
                          ),
                        ),
                      ),
                    const SizedBox(height: 18),
                    Text(
                      'Tus canjes',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 8),
                    if (mine.isEmpty)
                      const Text('Aun no tienes canjes.')
                    else
                      for (final redemption in mine)
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: const Icon(Icons.receipt_long),
                          title: Text(redemption.rewardName),
                          subtitle: Text(
                            redemption.adminMessage.isEmpty
                                ? redemption.status.label
                                : '${redemption.status.label}: ${redemption.adminMessage}',
                          ),
                        ),
                  ],
                );
              },
            );
          },
        );
      },
    );
  }
}
