import 'package:flutter/material.dart';

import '../models/clan.dart';
import '../services/game_state_service.dart';
import 'chat_screen.dart';

class ClansScreen extends StatelessWidget {
  const ClansScreen({super.key});

  void _showError(BuildContext context, String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _showCreateClanDialog(BuildContext context) async {
    final nameController = TextEditingController();
    final requirementController = TextEditingController();
    var isPrivate = false;

    final draft = await showDialog<_ClanDraft>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Crear clan'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  autofocus: true,
                  decoration: const InputDecoration(labelText: 'Nombre'),
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Privado'),
                  value: isPrivate,
                  onChanged: (value) {
                    setDialogState(() => isPrivate = value);
                  },
                ),
                TextField(
                  controller: requirementController,
                  decoration: const InputDecoration(
                    labelText: 'Requisito para entrar',
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.pop(
                  context,
                  _ClanDraft(
                    name: nameController.text.trim(),
                    isPrivate: isPrivate,
                    requirement: requirementController.text.trim(),
                  ),
                );
              },
              child: const Text('Crear'),
            ),
          ],
        ),
      ),
    );

    await Future<void>.delayed(const Duration(milliseconds: 120));
    nameController.dispose();
    requirementController.dispose();
    if (draft == null || draft.name.isEmpty) return;
    if (GameStateService.currentUserHasClan) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Ya perteneces a un clan.')));
      return;
    }
    if (GameStateService.currentProfile.points < 50) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Crear un clan cuesta 50 puntos')),
      );
      return;
    }

    GameStateService.saveClan(
      Clan(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        name: draft.name,
        ownerId: GameStateService.currentUserId,
        memberIds: [GameStateService.currentUserId],
        isPrivate: draft.isPrivate,
        requirement: draft.requirement,
      ),
    );
    GameStateService.addPlayerPoints(-50, reason: 'Crear clan');
    final error = GameStateService.lastError.value;
    if (error != null && context.mounted) _showError(context, error);
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<List<Clan>>(
      valueListenable: GameStateService.clans,
      builder: (context, clans, _) {
        final sortedClans = [...clans]
          ..sort((a, b) => b.totalPoints.compareTo(a.totalPoints));

        return Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFF214B86), Color(0xFF121722)],
            ),
          ),
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              const _ArenaHeader(),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const ChatScreen.global(),
                    ),
                  );
                },
                icon: const Icon(Icons.public),
                label: const Text('Chat global'),
              ),
              const SizedBox(height: 12),
              for (var i = 0; i < sortedClans.length; i++)
                _ClanCard(rank: i + 1, clan: sortedClans[i]),
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: () => _showCreateClanDialog(context),
                icon: const Icon(Icons.group_add),
                label: const Text('Crear clan'),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _ClanDraft {
  final String name;
  final bool isPrivate;
  final String requirement;

  const _ClanDraft({
    required this.name,
    required this.isPrivate,
    required this.requirement,
  });
}

class _ArenaHeader extends StatelessWidget {
  const _ArenaHeader();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.black.withAlpha(95),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white24),
      ),
      child: const Row(
        children: [
          Icon(Icons.shield, size: 44, color: Color(0xFFFFC857)),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Liga de clanes',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                ),
                Text(
                  'Solo miembros pueden usar el chat del clan.',
                  style: TextStyle(color: Colors.white70),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ClanCard extends StatelessWidget {
  final int rank;
  final Clan clan;

  const _ClanCard({required this.rank, required this.clan});

  @override
  Widget build(BuildContext context) {
    final currentUserId = GameStateService.currentUserId;
    final isMember = clan.memberIds.contains(currentUserId);
    final isPending = clan.pendingMemberIds.contains(currentUserId);
    final isOwner = clan.ownerId == currentUserId;
    final hasClan = GameStateService.currentUserHasClan;

    return Card(
      color: const Color(0xFF1D2635),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: rank == 1
                      ? const Color(0xFFFFC857)
                      : Colors.blueGrey,
                  child: Text('#$rank'),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        clan.name,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      Text(
                        '${clan.memberIds.length} miembros | ${clan.isPrivate ? 'Privado' : 'Publico'}',
                        style: const TextStyle(color: Colors.white70),
                      ),
                    ],
                  ),
                ),
                Text(
                  '${clan.totalPoints} pts',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            if (clan.requirement.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                clan.requirement,
                style: const TextStyle(color: Colors.white70),
              ),
            ],
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                OutlinedButton.icon(
                  onPressed: isMember
                      ? () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => ChatScreen(clan: clan),
                            ),
                          );
                        }
                      : null,
                  icon: const Icon(Icons.chat_bubble_outline),
                  label: const Text('Clan'),
                ),
                if (!isMember && !isPending)
                  FilledButton(
                    onPressed: hasClan
                        ? null
                        : () {
                            if (clan.isPrivate) {
                              GameStateService.requestClanJoin(clan.id);
                            } else {
                              GameStateService.joinClan(clan.id);
                            }
                            final error = GameStateService.lastError.value;
                            if (error != null) {
                              ScaffoldMessenger.of(
                                context,
                              ).showSnackBar(SnackBar(content: Text(error)));
                            }
                          },
                    child: Text(clan.isPrivate ? 'Solicitar' : 'Entrar'),
                  ),
                if (!isMember && isPending)
                  const Chip(label: Text('Pendiente')),
                if (isOwner && clan.pendingMemberIds.isNotEmpty)
                  OutlinedButton.icon(
                    onPressed: () => _showJoinRequests(context, clan),
                    icon: const Icon(Icons.person_add),
                    label: const Text('Solicitudes'),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showJoinRequests(BuildContext context, Clan clan) async {
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Solicitudes'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final userId in clan.pendingMemberIds)
              ListTile(
                title: Text(userId),
                trailing: FilledButton(
                  onPressed: () {
                    GameStateService.approveClanJoin(clan.id, userId);
                    Navigator.pop(context);
                  },
                  child: const Text('Aceptar'),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
