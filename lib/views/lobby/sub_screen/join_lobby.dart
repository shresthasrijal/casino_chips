import 'package:casino_chips/services/websocket_client.dart';
import 'package:casino_chips/views/game_screen.dart';
import 'package:flutter/material.dart';

class JoinLobbyScreen extends StatefulWidget {
  const JoinLobbyScreen({super.key});

  @override
  State<JoinLobbyScreen> createState() => _JoinLobbyScreenState();
}

class _JoinLobbyScreenState extends State<JoinLobbyScreen> {
  final _client = WebSocketClient();
  final _ipController = TextEditingController(text: '192.168.');
  final _usernameController = TextEditingController(text: 'Player');
  List<String> _players = [];
  String _status = 'Enter IP & username';

  void _connect() {
    // Set up ALL listeners BEFORE connecting
    _client.onPlayersUpdate = (p) {
      if (!mounted) return;
      setState(() {
        _players = p;
        _status = 'Connected: ${_players.length} players';
      });
    };

    _client.onGameStart = (data) {
      // ✅ Set state listeners BEFORE navigation
      _client.onStateUpdate = (chips, pot, turn) {
        // This will be used in GameScreen, but we can't update here
        // So just ensure it's attached early
      };
      _client.onChatMessage = (msg) {
        // Same
      };

      final players = List<String>.from(data['playerOrder']);
      final chips = Map<String, int>.from(data['chips']);
      final pot = data['pot'] as int;
      final turn = data['currentTurn'] as int;

      // Navigate WITH initial state
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => GameScreen(
            isHost: false,
            wsClient: _client,
            players: players,
            myUsername: _client.myUsername,
            hostUsername: 'Host',
            fixedDealer: data['fixedDealer'],
            initialChips: chips,
            initialPot: pot,
            initialCurrentTurn: turn,
          ),
        ),
      );
    };

    _client.connect(_ipController.text.trim(), _usernameController.text);
    setState(() => _status = 'Waiting for host...');
  }

  @override
  void dispose() {
    _client.disconnect();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Join Lobby')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: SingleChildScrollView(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              TextField(
                controller: _usernameController,
                decoration: const InputDecoration(labelText: 'Username'),
              ),
              const SizedBox(height: 20),
              TextField(
                controller: _ipController,
                decoration: const InputDecoration(labelText: 'Host IP'),
              ),
              const SizedBox(height: 20),
              ElevatedButton(onPressed: _connect, child: const Text('Join')),
              const SizedBox(height: 20),
              Text(_status),
              if (_players.isNotEmpty)
                Column(
                  children: [
                    const Text('Players:'),
                    ..._players.map((p) => Text(p)),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }
}
