import 'dart:async';

import 'package:flutter/material.dart';

import '../models/clan.dart';
import '../models/clan_message.dart';
import '../services/game_state_service.dart';
import '../services/realtime_service.dart';

class ChatScreen extends StatefulWidget {
  final Clan? clan;
  final bool isGlobal;

  const ChatScreen({super.key, required Clan this.clan}) : isGlobal = false;

  const ChatScreen.global({super.key}) : clan = null, isGlobal = true;

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _messageController = TextEditingController();
  final _scrollController = ScrollController();
  Timer? _timer;
  List<ClanMessage> _messages = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    if (!widget.isGlobal && widget.clan != null) {
      RealtimeService.joinClan(widget.clan!.id);
    }
    _loadMessages();
    _timer = Timer.periodic(
      const Duration(seconds: 2),
      (_) => _loadMessages(silent: true),
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    if (!widget.isGlobal && widget.clan != null) {
      RealtimeService.leaveClan(widget.clan!.id);
    }
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadMessages({bool silent = false}) async {
    final clan = widget.clan;
    if (!widget.isGlobal &&
        (clan == null ||
            !clan.memberIds.contains(GameStateService.currentUserId))) {
      if (!mounted) return;
      setState(() => _loading = false);
      return;
    }
    try {
      final messages = widget.isGlobal
          ? await GameStateService.fetchGlobalMessages()
          : await GameStateService.fetchClanMessages(clan!.id);
      if (!mounted) return;
      setState(() {
        _messages = messages;
        _loading = false;
      });
      if (!silent) _scrollToBottom();
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
      );
    });
  }

  Future<void> _send() async {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;

    _messageController.clear();
    if (widget.isGlobal) {
      GameStateService.sendGlobalMessage(text: text);
    } else {
      GameStateService.sendClanMessage(clanId: widget.clan!.id, text: text);
    }
    setState(() {
      _messages = [
        ..._messages,
        ClanMessage(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          clanId: widget.isGlobal ? 'global' : widget.clan!.id,
          userId: GameStateService.currentUserId,
          userName: GameStateService.currentUserName,
          text: text,
          createdAt: DateTime.now(),
        ),
      ];
    });
    _scrollToBottom();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.isGlobal ? 'Chat global' : 'Chat: ${widget.clan!.name}',
        ),
      ),
      body: Column(
        children: [
          if (!widget.isGlobal &&
              !widget.clan!.memberIds.contains(GameStateService.currentUserId))
            const Expanded(
              child: Center(
                child: Text('Solo los miembros pueden chatear en este clan.'),
              ),
            )
          else
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : ListView.builder(
                      controller: _scrollController,
                      padding: const EdgeInsets.all(12),
                      itemCount: _messages.length,
                      itemBuilder: (context, index) {
                        final message = _messages[index];
                        final mine =
                            message.userId == GameStateService.currentUserId;
                        return Align(
                          alignment: mine
                              ? Alignment.centerRight
                              : Alignment.centerLeft,
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 320),
                            child: Card(
                              color: mine
                                  ? const Color(0xFF235B45)
                                  : const Color(0xFF202936),
                              child: Padding(
                                padding: const EdgeInsets.all(10),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      message.userName,
                                      style: const TextStyle(
                                        fontSize: 12,
                                        color: Colors.white70,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(message.text),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
            ),
          if (widget.isGlobal ||
              widget.clan!.memberIds.contains(GameStateService.currentUserId))
            SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _messageController,
                        minLines: 1,
                        maxLines: 4,
                        decoration: InputDecoration(
                          hintText: 'Mensaje al clan',
                          prefixIcon: Icon(
                            widget.isGlobal ? Icons.public : Icons.chat,
                          ),
                        ),
                        onSubmitted: (_) => _send(),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton.filled(
                      tooltip: 'Enviar',
                      onPressed: _send,
                      icon: const Icon(Icons.send),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
