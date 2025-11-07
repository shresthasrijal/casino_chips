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
  // final _betController = TextEditingController();

  @override
  void initState() {
    super.initState();
    if (widget.isHost) {
      widget.hostServer!.onChatMessage = (msg) =>
          setState(() => _messages.add(msg));
      widget.hostServer!.onCustomMessage = (data, socket) {
        final username = widget.hostServer!.clientUsernames[socket];
        if (username == null || players.indexOf(username) != currentTurn) {
          return;
        }

        String actionText = '';
        if (data['type'] == 'bet') {
          final amount = data['amount'] as int;
          final currentPlayer = players[currentTurn];
          if (amount < 1 || amount > (chips[currentPlayer] ?? 0)) return;
          chips[currentPlayer] = (chips[currentPlayer] ?? 0) - amount;
          pot += amount;
          actionText = '$username bet $amount';
        } else if (data['type'] == 'check') {
          actionText = '$username checked';
        }

        currentTurn = (currentTurn + 1) % players.length;
        setState(() {});
        widget.hostServer!.broadcast({
          'type': 'state_update',
          'chips': chips,
          'pot': pot,
          'currentTurn': currentTurn,
        });
        if (actionText.isNotEmpty) {
          widget.hostServer!.broadcast({
            'type': 'chat',
            'from': 'System',
            'text': actionText,
          });
        }
      };
    } else {
      widget.wsClient!.onChatMessage = (msg) =>
          setState(() => _messages.add(msg));
      widget.wsClient!.onStateUpdate = (c, p, t) => setState(() {
        chips = c;
        pot = p;
        currentTurn = t;
      });
      widget.wsClient!.onGameEnd = (winner) => setState(() {
        _messages.add('Game ended. Winner: $winner');
        currentTurn = -1;
      });
    }
  }

  void _betAmount(int amount) {
    final currentPlayer = players[currentTurn];
    if (amount > (chips[currentPlayer] ?? 0)) return;
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
      widget.hostServer!.broadcast({
        'type': 'chat',
        'from': 'System',
        'text': '$myUsername bet $amount',
      });
    } else if (currentPlayer == myUsername) {
      widget.wsClient!.send({'type': 'bet', 'amount': amount});
    }
  }

  // void _bet() {
  //   final amount = int.tryParse(_betController.text) ?? 0;
  //   final currentPlayer = players[currentTurn];
  //   if (amount < 1 || amount > (chips[currentPlayer] ?? 0)) return;

  //   if (widget.isHost) {
  //     chips[currentPlayer] = (chips[currentPlayer] ?? 0) - amount;
  //     pot += amount;
  //     currentTurn = (currentTurn + 1) % players.length;
  //     setState(() {});
  //     widget.hostServer!.broadcast({
  //       'type': 'state_update',
  //       'chips': chips,
  //       'pot': pot,
  //       'currentTurn': currentTurn,
  //     });
  //     _messages.add('You bet $amount');
  //   } else if (currentPlayer == myUsername) {
  //     widget.wsClient!.send({'type': 'bet', 'amount': amount});
  //   }
  //   _betController.clear();
  // }

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
      widget.hostServer!.broadcast({
        'type': 'chat',
        'from': 'System',
        'text': '$myUsername checked',
      });
    } else {
      widget.wsClient!.send({'type': 'check'});
    }
  }

  void _endGame() {
    showDialog<String>(
      context: context,
      builder: (BuildContext context) {
        String selectedWinner = players[0];
        return StatefulBuilder(
          builder: (context, setDialogState) => AlertDialog(
            title: const Text('End Game'),
            content: DropdownButtonFormField<String>(
              initialValue: selectedWinner,
              items: players
                  .map((p) => DropdownMenuItem(value: p, child: Text(p)))
                  .toList(),
              onChanged: (v) {
                if (v != null) {
                  setDialogState(() => selectedWinner = v);
                }
              },
              decoration: const InputDecoration(labelText: 'Select Winner'),
            ),
            actions: <Widget>[
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, selectedWinner),
                child: const Text('End'),
              ),
            ],
          ),
        );
      },
    ).then((winner) {
      if (winner != null && widget.isHost) {
        widget.hostServer!.broadcast({'type': 'game_end', 'winner': winner});
        setState(() {
          _messages.add('Game ended. Winner: $winner');
          currentTurn = -1;
        });
      }
    });
  }

  bool get isMyTurn =>
      currentTurn >= 0 && players.indexOf(myUsername) == currentTurn;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Casino Chips'),
        actions: widget.isHost
            ? [
                IconButton(
                  icon: const Icon(Icons.stop),
                  onPressed: currentTurn >= 0 ? _endGame : null,
                ),
              ]
            : null,
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 36),
            child: Text(
              currentTurn >= 0 ? 'Pot: $pot' : 'Game Over - Pot: $pot',
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
              child: Column(
                children: [
                  Wrap(
                    spacing: 8,
                    children: [1, 5, 10, 25, 50, 100, 500, 1000]
                        .map(
                          (val) => ElevatedButton(
                            onPressed: (chips[players[currentTurn]] ?? 0) >= val
                                ? () => _betAmount(val)
                                : null,
                            child: Text('$val'),
                          ),
                        )
                        .toList(),
                  ),
                  ElevatedButton(onPressed: _check, child: const Text('Check')),
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
