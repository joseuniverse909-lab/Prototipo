import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';

import '../models/game_event.dart';
import '../models/player_profile.dart';
import '../models/reward.dart';
import '../models/reward_redemption.dart';
import '../models/validation_photo.dart';
import '../models/zone_model.dart';
import '../services/game_state_service.dart';

class AdminPanelScreen extends StatefulWidget {
  final List<GameEvent> events;
  final List<Zone> zones;
  final ValueChanged<GameEvent> onSaveEvent;
  final ValueChanged<String> onDeleteEvent;
  final void Function(String zoneId, ZoneState state) onZoneStateChanged;

  const AdminPanelScreen({
    super.key,
    required this.events,
    required this.zones,
    required this.onSaveEvent,
    required this.onDeleteEvent,
    required this.onZoneStateChanged,
  });

  @override
  State<AdminPanelScreen> createState() => _AdminPanelScreenState();
}

class _AdminPanelScreenState extends State<AdminPanelScreen> {
  final _eventNameController = TextEditingController();
  final _rulesController = TextEditingController();
  final _bonusController = TextEditingController(text: '100');
  GameEventType _type = GameEventType.clanWar;
  int _durationHours = 24;
  String? _editingEventId;

  @override
  void dispose() {
    _eventNameController.dispose();
    _rulesController.dispose();
    _bonusController.dispose();
    super.dispose();
  }

  Future<bool> _waitForDialogToClose() async {
    await Future<void>.delayed(const Duration(milliseconds: 160));
    return mounted;
  }

  ImageProvider? _photoProvider(ValidationPhoto photo) {
    try {
      if (photo.imageBase64.isNotEmpty) {
        return MemoryImage(base64Decode(photo.imageBase64));
      }
      if (photo.localPath.isNotEmpty) return FileImage(File(photo.localPath));
    } catch (_) {
      return null;
    }
    return null;
  }

  Future<void> _approvePhoto(ValidationPhoto photo) async {
    final controller = TextEditingController(text: '50');
    final points = await showDialog<int>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Asignar puntos'),
        content: TextField(
          controller: controller,
          autofocus: true,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(labelText: 'Puntos'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () {
              FocusScope.of(context).unfocus();
              Navigator.pop(context, int.tryParse(controller.text.trim()) ?? 0);
            },
            child: const Text('Aprobar'),
          ),
        ],
      ),
    );
    if (!await _waitForDialogToClose()) {
      controller.dispose();
      return;
    }
    controller.dispose();
    if (points == null) return;
    GameStateService.updateValidationStatus(
      photo.id,
      ValidationStatus.approved,
      awardedPoints: points,
    );
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('Foto aprobada: +$points pts')));
  }

  Future<void> _editReward([Reward? reward]) async {
    final nameController = TextEditingController(text: reward?.name ?? '');
    final descriptionController = TextEditingController(
      text: reward?.description ?? '',
    );
    final costController = TextEditingController(
      text: reward?.cost.toString() ?? '100',
    );

    final saved = await showDialog<Reward>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(reward == null ? 'Crear recompensa' : 'Editar recompensa'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(labelText: 'Nombre'),
              ),
              TextField(
                controller: descriptionController,
                decoration: const InputDecoration(labelText: 'Descripcion'),
              ),
              TextField(
                controller: costController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Costo'),
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
              FocusScope.of(context).unfocus();
              Navigator.pop(
                context,
                Reward(
                  id:
                      reward?.id ??
                      DateTime.now().millisecondsSinceEpoch.toString(),
                  name: nameController.text.trim(),
                  description: descriptionController.text.trim(),
                  cost: int.tryParse(costController.text.trim()) ?? 0,
                ),
              );
            },
            child: const Text('Guardar'),
          ),
        ],
      ),
    );

    if (!await _waitForDialogToClose()) {
      nameController.dispose();
      descriptionController.dispose();
      costController.dispose();
      return;
    }
    nameController.dispose();
    descriptionController.dispose();
    costController.dispose();
    if (saved == null || saved.name.isEmpty) return;
    GameStateService.saveReward(saved);
  }

  void _saveEvent() {
    final name = _eventNameController.text.trim();
    if (name.isEmpty) return;

    final now = DateTime.now();
    widget.onSaveEvent(
      GameEvent(
        id: _editingEventId ?? now.millisecondsSinceEpoch.toString(),
        name: name,
        type: _type,
        rules: _rulesController.text.trim(),
        startsAt: now,
        endsAt: now.add(Duration(hours: _durationHours)),
        bonusPoints: int.tryParse(_bonusController.text.trim()) ?? 0,
      ),
    );
    setState(() {
      _editingEventId = null;
      _eventNameController.clear();
      _rulesController.clear();
      _bonusController.text = '100';
      _type = GameEventType.clanWar;
      _durationHours = 24;
    });
  }

  void _startClanWar() {
    final now = DateTime.now();
    widget.onSaveEvent(
      GameEvent(
        id: now.millisecondsSinceEpoch.toString(),
        name: 'Guerra de clanes',
        type: GameEventType.clanWar,
        rules: 'Suma puntos claimeando zonas y completando actividades.',
        startsAt: now,
        endsAt: now.add(Duration(hours: _durationHours)),
        bonusPoints: int.tryParse(_bonusController.text.trim()) ?? 100,
      ),
    );
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Guerra de clanes iniciada')));
  }

  void _editEvent(GameEvent event) {
    setState(() {
      _editingEventId = event.id;
      _eventNameController.text = event.name;
      _rulesController.text = event.rules;
      _bonusController.text = event.bonusPoints.toString();
      _type = event.type;
      _durationHours = event.duration.inHours.clamp(1, 168);
    });
  }

  Future<void> _resolveRedemption(
    RewardRedemption redemption,
    RedemptionStatus status,
  ) async {
    final controller = TextEditingController(
      text: status == RedemptionStatus.delivered
          ? 'Tu recompensa fue aprobada. Coordina la entrega con el admin.'
          : 'Tu canje fue rechazado.',
    );
    final message = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Mensaje al jugador'),
        content: TextField(
          controller: controller,
          minLines: 2,
          maxLines: 4,
          decoration: const InputDecoration(labelText: 'Mensaje'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () {
              FocusScope.of(context).unfocus();
              Navigator.pop(context, controller.text.trim());
            },
            child: const Text('Enviar'),
          ),
        ],
      ),
    );
    if (!await _waitForDialogToClose()) {
      controller.dispose();
      return;
    }
    controller.dispose();
    if (message == null) return;
    GameStateService.updateRedemption(
      redemption,
      status: status,
      adminMessage: message,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Panel admin')),
      body: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          _AdminSection(
            icon: Icons.event,
            title: 'Eventos',
            child: _buildEventsSection(),
          ),
          _AdminSection(
            icon: Icons.photo_camera,
            title: 'Validacion de fotos',
            child: _buildPhotosSection(),
          ),
          _AdminSection(
            icon: Icons.card_giftcard,
            title: 'Recompensas y canjes',
            child: _buildRewardsSection(),
          ),
          _AdminSection(
            icon: Icons.stars,
            title: 'Puntos',
            child: _buildPointsSection(),
          ),
          _AdminSection(
            icon: Icons.map,
            title: 'Zonas',
            child: _buildZonesSection(),
          ),
        ],
      ),
    );
  }

  Widget _buildEventsSection() {
    return ValueListenableBuilder<List<GameEvent>>(
      valueListenable: GameStateService.events,
      builder: (context, events, _) {
        final sortedEvents = [...events]
          ..sort((a, b) => b.startsAt.compareTo(a.startsAt));

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            FilledButton.icon(
              onPressed: _startClanWar,
              icon: const Icon(Icons.sports_martial_arts),
              label: const Text('Iniciar guerra de clanes'),
            ),
            const SizedBox(height: 12),
            SegmentedButton<GameEventType>(
              segments: GameEventType.values
                  .map(
                    (type) =>
                        ButtonSegment(value: type, label: Text(type.label)),
                  )
                  .toList(),
              selected: {_type},
              onSelectionChanged: (selected) {
                setState(() => _type = selected.first);
              },
            ),
            TextField(
              controller: _eventNameController,
              decoration: const InputDecoration(labelText: 'Nombre del evento'),
            ),
            TextField(
              controller: _rulesController,
              decoration: const InputDecoration(labelText: 'Reglas'),
              minLines: 2,
              maxLines: 4,
            ),
            TextField(
              controller: _bonusController,
              decoration: const InputDecoration(labelText: 'Puntos extra'),
              keyboardType: TextInputType.number,
            ),
            Row(
              children: [
                const Text('Duracion'),
                Expanded(
                  child: Slider(
                    min: 1,
                    max: 168,
                    divisions: 167,
                    value: _durationHours.toDouble(),
                    label: '$_durationHours h',
                    onChanged: (value) {
                      setState(() => _durationHours = value.round());
                    },
                  ),
                ),
                Text('$_durationHours h'),
              ],
            ),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ChoiceChip(
                  selected: _durationHours == 1,
                  label: const Text('1 h'),
                  onSelected: (_) => setState(() => _durationHours = 1),
                ),
                ChoiceChip(
                  selected: _durationHours == 6,
                  label: const Text('6 h'),
                  onSelected: (_) => setState(() => _durationHours = 6),
                ),
                ChoiceChip(
                  selected: _durationHours == 24,
                  label: const Text('24 h'),
                  onSelected: (_) => setState(() => _durationHours = 24),
                ),
              ],
            ),
            const SizedBox(height: 10),
            FilledButton.icon(
              onPressed: _saveEvent,
              icon: const Icon(Icons.save),
              label: Text(
                _editingEventId == null ? 'Crear evento' : 'Guardar cambios',
              ),
            ),
            const Divider(),
            for (final event in sortedEvents)
              Card(
                color: const Color(0xFF101722),
                child: ListTile(
                  leading: Icon(
                    event.isRunning ? Icons.play_circle : Icons.event,
                    color: event.isRunning
                        ? Colors.greenAccent
                        : Colors.white70,
                  ),
                  title: Text(event.name),
                  subtitle: Text(
                    '${event.type.label} | ${event.bonusPoints} pts | ${event.duration.inHours} h',
                  ),
                  trailing: Wrap(
                    children: [
                      IconButton(
                        tooltip: 'Editar',
                        onPressed: () => _editEvent(event),
                        icon: const Icon(Icons.edit),
                      ),
                      IconButton(
                        tooltip: 'Eliminar',
                        onPressed: () => widget.onDeleteEvent(event.id),
                        icon: const Icon(Icons.delete),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _buildPhotosSection() {
    return ValueListenableBuilder<List<ValidationPhoto>>(
      valueListenable: GameStateService.validationPhotos,
      builder: (context, photos, _) {
        final pending = photos
            .where((photo) => photo.status == ValidationStatus.pending)
            .toList();
        if (pending.isEmpty) return const Text('No hay fotos pendientes.');

        return Column(
          children: [
            for (final photo in pending)
              Card(
                color: const Color(0xFF101722),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _ValidationThumb(provider: _photoProvider(photo)),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  photo.userName,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  photo.note.isEmpty ? 'Sin nota' : photo.note,
                                  style: const TextStyle(color: Colors.white70),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          FilledButton.icon(
                            onPressed: () => _approvePhoto(photo),
                            icon: const Icon(Icons.check),
                            label: const Text('Aprobar'),
                          ),
                          OutlinedButton.icon(
                            onPressed: () {
                              GameStateService.updateValidationStatus(
                                photo.id,
                                ValidationStatus.rejected,
                              );
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Foto rechazada')),
                              );
                            },
                            icon: const Icon(Icons.close),
                            label: const Text('Rechazar'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _buildRewardsSection() {
    return Column(
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: FilledButton.icon(
            onPressed: () => _editReward(),
            icon: const Icon(Icons.add),
            label: const Text('Crear recompensa'),
          ),
        ),
        ValueListenableBuilder<List<Reward>>(
          valueListenable: GameStateService.rewards,
          builder: (context, rewards, _) => Column(
            children: [
              for (final reward in rewards)
                Card(
                  color: const Color(0xFF101722),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const CircleAvatar(
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
                                  Text(
                                    '${reward.cost} pts',
                                    style: const TextStyle(
                                      color: Colors.white70,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        if (reward.description.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          Text(
                            reward.description,
                            style: const TextStyle(color: Colors.white70),
                          ),
                        ],
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            OutlinedButton.icon(
                              onPressed: () => _editReward(reward),
                              icon: const Icon(Icons.edit),
                              label: const Text('Editar'),
                            ),
                            OutlinedButton.icon(
                              onPressed: () =>
                                  GameStateService.deleteReward(reward.id),
                              icon: const Icon(Icons.delete),
                              label: const Text('Eliminar'),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
        const Divider(),
        ValueListenableBuilder<List<RewardRedemption>>(
          valueListenable: GameStateService.redemptions,
          builder: (context, redemptions, _) {
            final pending = redemptions
                .where((item) => item.status == RedemptionStatus.pending)
                .toList();
            if (pending.isEmpty) return const Text('No hay canjes pendientes.');

            return Column(
              children: [
                for (final redemption in pending)
                  Card(
                    color: const Color(0xFF101722),
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const CircleAvatar(
                                child: Icon(Icons.receipt_long),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      redemption.rewardName,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    Text(
                                      '${redemption.userName} | ${redemption.cost} pts',
                                      style: const TextStyle(
                                        color: Colors.white70,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              FilledButton.icon(
                                onPressed: () => _resolveRedemption(
                                  redemption,
                                  RedemptionStatus.delivered,
                                ),
                                icon: const Icon(Icons.check),
                                label: const Text('Entregar'),
                              ),
                              OutlinedButton.icon(
                                onPressed: () => _resolveRedemption(
                                  redemption,
                                  RedemptionStatus.rejected,
                                ),
                                icon: const Icon(Icons.close),
                                label: const Text('Rechazar'),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
      ],
    );
  }

  Future<void> _givePoints(PlayerProfile user) async {
    final controller = TextEditingController(text: '50');
    final amount = await showDialog<int>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Dar puntos a ${user.name}'),
        content: TextField(
          controller: controller,
          autofocus: true,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(labelText: 'Puntos'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () {
              FocusScope.of(context).unfocus();
              Navigator.pop(context, int.tryParse(controller.text.trim()) ?? 0);
            },
            child: const Text('Aplicar'),
          ),
        ],
      ),
    );
    if (!await _waitForDialogToClose()) {
      controller.dispose();
      return;
    }
    controller.dispose();
    if (amount == null || amount == 0) return;
    GameStateService.addPlayerPoints(
      amount,
      userId: user.id,
      reason: 'Puntos admin',
    );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${user.name}: ${amount > 0 ? '+' : ''}$amount pts'),
      ),
    );
  }

  Widget _buildPointsSection() {
    return ValueListenableBuilder<List<PlayerProfile>>(
      valueListenable: GameStateService.users,
      builder: (context, users, _) {
        if (users.isEmpty) return const Text('No hay usuarios cargados.');
        return Column(
          children: [
            for (final user in users)
              Card(
                color: const Color(0xFF101722),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const CircleAvatar(child: Icon(Icons.person)),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  user.name,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  user.email.isEmpty ? user.id : user.email,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(color: Colors.white70),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Chip(label: Text('${user.points} pts')),
                          FilledButton.icon(
                            onPressed: () => _givePoints(user),
                            icon: const Icon(Icons.add),
                            label: const Text('Dar puntos'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _buildZonesSection() {
    return ValueListenableBuilder<List<Zone>>(
      valueListenable: GameStateService.zones,
      builder: (context, zones, _) => Column(
        children: [
          for (final zone in zones)
            Card(
              color: const Color(0xFF101722),
              child: ListTile(
                leading: CircleAvatar(backgroundColor: zone.fillColor),
                title: Text(zone.name),
                subtitle: Text(
                  '${zone.state.label} | score ${zone.priorityScore.toStringAsFixed(2)}',
                ),
                trailing: DropdownButton<ZoneState>(
                  value: zone.state,
                  items: ZoneState.values
                      .map(
                        (state) => DropdownMenuItem(
                          value: state,
                          child: Text(state.label),
                        ),
                      )
                      .toList(),
                  onChanged: (state) {
                    if (state != null) {
                      widget.onZoneStateChanged(zone.id, state);
                    }
                  },
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _AdminSection extends StatelessWidget {
  final IconData icon;
  final String title;
  final Widget child;

  const _AdminSection({
    required this.icon,
    required this.title,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      color: const Color(0xFF17202C),
      child: ExpansionTile(
        leading: Icon(icon),
        title: Text(title),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        children: [child],
      ),
    );
  }
}

class _ValidationThumb extends StatelessWidget {
  final ImageProvider? provider;

  const _ValidationThumb({required this.provider});

  @override
  Widget build(BuildContext context) {
    if (provider == null) {
      return const SizedBox(
        width: 54,
        height: 54,
        child: Icon(Icons.broken_image),
      );
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(6),
      child: Image(image: provider!, width: 54, height: 54, fit: BoxFit.cover),
    );
  }
}
