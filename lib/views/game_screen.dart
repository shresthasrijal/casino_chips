// views/game_screen.dart (turn-based betting + chat + state sync)
import 'package:casino_chips/services/host_server.dart';
import 'package:casino_chips/services/websocket_client.dart';
import 'package:flutter/material.dart';

class GameScreen extends StatefulWidget {
  final bool isHost;
  final HostServer? hostServer;
  final WebSocketClient? wsClient;
  final List<String> players;
  final String myUsername;
  final String hostUsername;
  final bool fixedDealer;
  final Map<String, int> initialChips;
  final int initialPot;
  final int initialCurrentTurn;

  const GameScreen({
    super.key,
    required this.isHost,
    this.hostServer,
    this.wsClient,
    required this.players,
    required this.myUsername,
    required this.hostUsername,
    required this.fixedDealer,
    required this.initialChips,
    required this.initialPot,
    required this.initialCurrentTurn,
  });

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> {
  late List<String> players = widget.players;
  late String myUsername = widget.myUsername;
  late String hostUsername = widget.hostUsername;
  late bool fixedDealer = widget.fixedDealer;
  late Map<String, int> chips = Map.from(widget.initialChips);
  late int pot = widget.initialPot;
  late int currentTurn = widget.initialCurrentTurn;

  final _messages = <String>[];
  final _chatController = TextEditingController();
  final _betController = TextEditingController();

  @override
  void initState() {
    super.initState();
    if (widget.isHost) {
      widget.hostServer!.onCustomMessage = (data, socket) {
        final username = widget.hostServer!.clientUsernames[socket];
        if (username == null || players.indexOf(username) != currentTurn) {
          return;
        }

        if (data['type'] == 'bet') {
          final amount = data['amount'] as int;
          final currentPlayer = players[currentTurn];
          if (amount < 1 || amount > (chips[currentPlayer] ?? 0)) return;
          chips[currentPlayer] = (chips[currentPlayer] ?? 0) - amount;
          pot += amount;
        } else if (data['type'] == 'check') {
          // just pass turn
        }

        currentTurn = (currentTurn + 1) % players.length;
        setState(() {});
        widget.hostServer!.broadcast({
          'type': 'state_update',
          'chips': chips,
          'pot': pot,
          'currentTurn': currentTurn,
        });
      };
    } else {
      widget.wsClient!.onChatMessage = (msg) =>
          setState(() => _messages.add(msg));
      widget.wsClient!.onStateUpdate = (c, p, t) => setState(() {
        chips = c;
        pot = p;
        currentTurn = t;
      });
    }
  }

  void _bet() {
    final amount = int.tryParse(_betController.text) ?? 0;
    final currentPlayer = players[currentTurn];
    if (amount < 1 || amount > (chips[currentPlayer] ?? 0)) return;

    if (widget.isHost) {
      chips[currentPlayer] = (chips[currentPlayer] ?? 0) - amount;
      pot += amount;
      currentTurn = (currentTurn + 1) % players.length;
      setState(() {});
      widget.hostServer!.broadcast({
        'type': 'state_update',
        'chips': chips,
        'pot': pot,
        'currentTurn': currentTurn,
      });
      _messages.add('You bet $amount');
    } else if (currentPlayer == myUsername) {
      widget.wsClient!.send({'type': 'bet', 'amount': amount});
    }
    _betController.clear();
  }

  void _sendChat() {
    final text = _chatController.text.trim();
    if (text.isEmpty) return;
    setState(() => _messages.add('You ($myUsername): $text'));
    final map = {'type': 'chat', 'text': text};
    if (widget.isHost) {
      widget.hostServer!.broadcast({
        'type': 'chat',
        'from': myUsername,
        'text': text,
      });
    } else {
      widget.wsClient!.send(map);
    }
    _chatController.clear();
  }

  void _check() {
    if (widget.isHost) {
      currentTurn = (currentTurn + 1) % players.length;
      setState(() {});
      widget.hostServer!.broadcast({
        'type': 'state_update',
        'chips': chips,
        'pot': pot,
        'currentTurn': currentTurn,
      });
      _messages.add('You checked');
    } else {
      widget.wsClient!.send({'type': 'check'});
    }
  }

  bool get isMyTurn => players.indexOf(myUsername) == currentTurn;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Casino Chips')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 36),
            child: Text(
              'Pot: $pot',
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(
            flex: 2,
            child: ListView.builder(
              itemCount: players.length,
              itemBuilder: (c, i) {
                final p = players[i];
                final isMe = p == myUsername;
                final isDealer = fixedDealer && p == hostUsername;
                final isTurn = i == currentTurn;
                return ListTile(
                  tileColor: isTurn
                      ? Colors.green.withValues(alpha: 0.3)
                      : null,
                  title: Text(
                    '$p${isMe ? ' (You)' : ''}${isDealer ? ' (Dealer)' : ''}${isTurn ? ' ← TURN' : ''}: ${chips[p]} chips',
                  ),
                );
              },
            ),
          ),
          Expanded(
            flex: 3,
            child: ListView.builder(
              itemCount: _messages.length,
              itemBuilder: (_, i) => ListTile(title: Text(_messages[i])),
            ),
          ),
          if (isMyTurn)
            Padding(
              padding: const EdgeInsets.all(8),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _betController,
                      decoration: const InputDecoration(
                        labelText: 'Bet amount',
                      ),
                      keyboardType: TextInputType.number,
                    ),
                  ),
                  ElevatedButton(onPressed: _check, child: const Text('Check')),
                  ElevatedButton(onPressed: _bet, child: const Text('Bet')),
                ],
              ),
            ),
          Padding(
            padding: const EdgeInsets.all(8),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _chatController,
                    decoration: const InputDecoration(hintText: 'Chat'),
                  ),
                ),
                IconButton(onPressed: _sendChat, icon: const Icon(Icons.send)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
