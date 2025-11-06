// views/lobby/sub_screen/join_lobby.dart
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

  @override
  void initState() {
    super.initState();
    // Optional: preload last used IP/username from shared prefs later
  }

  void _connect() {
    final ip = _ipController.text.trim();
    final username = _usernameController.text.trim();

    if (ip.isEmpty || username.isEmpty) {
      setState(() => _status = 'IP and username cannot be empty');
      return;
    }

    // ✅ CRITICAL: Set UP ALL CALLBACKS BEFORE CONNECTING
    _client.onPlayersUpdate = (players) {
      if (!mounted) return;
      setState(() {
        _players = players;
        _status = 'Connected: ${players.length} players';
      });
    };

    _client.onChatMessage = (msg) {
      // Will be overridden in GameScreen, but prevents message loss during transition
    };

    _client.onStateUpdate = (chips, pot, turn) {
      // Same — just ensure handler exists so message isn’t dropped
    };

    _client.onGameStart = (data) {
      final players = List<String>.from(data['playerOrder']);
      final chips = Map<String, int>.from(data['chips']);
      final pot = data['pot'] as int;
      final turn = data['currentTurn'] as int;
      final fixedDealer = data['fixedDealer'] as bool;

      // Navigate to game WITH full state
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => GameScreen(
            isHost: false,
            wsClient: _client,
            players: players,
            myUsername: _client.myUsername,
            hostUsername: 'Host',
            fixedDealer: fixedDealer,
            initialChips: chips,
            initialPot: pot,
            initialCurrentTurn: turn,
          ),
        ),
      );
    };

    setState(() => _status = 'Connecting...');
    _client.connect(ip, username);
  }

  @override
  void dispose() {
    _client.disconnect();
    _ipController.dispose();
    _usernameController.dispose();
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
                maxLines: 1,
              ),
              const SizedBox(height: 20),
              TextField(
                controller: _ipController,
                decoration: const InputDecoration(
                  labelText: 'Host IP (e.g. 192.168.1.105)',
                ),
                maxLines: 1,
                keyboardType: TextInputType.text,
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _connect,
                  child: const Text('Join Lobby'),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                _status,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 16),
              ),
              const SizedBox(height: 16),
              if (_players.isNotEmpty)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Current Players:',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    ..._players.map(
                      (p) => Padding(
                        padding: const EdgeInsets.symmetric(vertical: 2),
                        child: Text('• $p'),
                      ),
                    ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }
}
