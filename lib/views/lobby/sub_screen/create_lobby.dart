import 'package:casino_chips/services/host_server.dart';
import 'package:casino_chips/utils/network_utils.dart';
import 'package:casino_chips/views/game_screen.dart';
import 'package:flutter/material.dart';

// views/lobby/sub_screen/create_lobby.dart (no host username input, fixed "Host")
class CreateLobbyScreen extends StatefulWidget {
  const CreateLobbyScreen({super.key});

  @override
  State<CreateLobbyScreen> createState() => _CreateLobbyScreenState();
}

// views/lobby/sub_screen/create_lobby.dart
class _CreateLobbyScreenState extends State<CreateLobbyScreen> {
  final _server = HostServer();
  String? _ip;
  List<String> _players = ['Host']; // Start with Host
  int selectedCoins = 1000;
  bool fixedDealer = true;

  double bottomArea = 0;

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      setState(() {
        bottomArea = MediaQuery.of(context).viewInsets.bottom;
      });
    });
    _startHost();
  }

  Future<void> _startHost() async {
    await _server.startServer(
      onLog: (msg) => debugPrint(msg),
      onPlayersUpdate: (p) {
        if (mounted) setState(() => _players = p);
      },
    );
    final ip = await getLocalIp();
    setState(() => _ip = ip);
  }

  @override
  void dispose() {
    _server.stopServer();
    super.dispose();
  }

  void _goToGame() {
    final initialChips = {for (var p in _players) p: selectedCoins};
    final gameData = {
      'type': 'game_start',
      'playerOrder': _players,
      'startingCoins': selectedCoins,
      'fixedDealer': fixedDealer,
      'chips': initialChips,
      'pot': 0,
      'currentTurn': 0,
    };
    _server.broadcast(gameData);

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => GameScreen(
          isHost: true,
          hostServer: _server,
          players: _players,
          myUsername: 'Host',
          hostUsername: 'Host',
          fixedDealer: fixedDealer,
          initialChips: initialChips,
          initialPot: 0,
          initialCurrentTurn: 0,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Create Lobby')),
      body: _ip == null
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(16),
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Card(
                      color: Colors.green.shade700,
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Text(
                          'IP: $_ip\nShare this with players',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    const Text(
                      'Players Joined',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),

                    // ✅ FIXED: No Expanded! Just render list with natural height
                    if (_players.length == 1)
                      const Center(
                        child: Padding(
                          padding: EdgeInsets.symmetric(vertical: 32),
                          child: Text(
                            'Waiting for players...',
                            style: TextStyle(color: Colors.grey),
                          ),
                        ),
                      )
                    else
                      ConstrainedBox(
                        constraints: BoxConstraints(
                          maxHeight: 300, // prevents huge list
                        ),
                        child: ReorderableListView.builder(
                          shrinkWrap: true, // ✅ Critical!
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: _players.length,
                          itemBuilder: (c, i) => ListTile(
                            key: ValueKey(_players[i]),
                            leading: i == 0
                                ? const Icon(Icons.star, color: Colors.amber)
                                : null,
                            title: Text(
                              _players[i],
                              style: TextStyle(
                                fontWeight: i == 0 ? FontWeight.bold : null,
                              ),
                            ),
                            trailing: i == 0
                                ? null
                                : const Icon(Icons.drag_handle),
                          ),
                          onReorder: (old, anew) {
                            if (old == 0 || anew == 0) return;
                            setState(() {
                              if (old < anew) anew--;
                              final p = _players.removeAt(old);
                              _players.insert(anew, p);
                            });
                          },
                        ),
                      ),

                    const SizedBox(height: 16),
                    Row(
                      children: [
                        const Text('Starting Chips: '),
                        DropdownButton<int>(
                          value: selectedCoins,
                          items: [500, 1000, 2000, 5000]
                              .map(
                                (v) => DropdownMenuItem(
                                  value: v,
                                  child: Text('$v'),
                                ),
                              )
                              .toList(),
                          onChanged: (v) => setState(() => selectedCoins = v!),
                        ),
                      ],
                    ),
                    CheckboxListTile(
                      title: const Text('Host is Fixed Dealer'),
                      value: fixedDealer,
                      onChanged: (v) => setState(() => fixedDealer = v!),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _players.length >= 2
                            ? Colors.green
                            : Colors.grey,
                        minimumSize: const Size(double.infinity, 50),
                      ),
                      onPressed: _players.length >= 2 ? _goToGame : null,
                      child: Text(
                        _players.length >= 2
                            ? 'Start Game (${_players.length} players)'
                            : 'Need 1+ player to start',
                      ),
                    ),
                    SizedBox(height: bottomArea),
                  ],
                ),
              ),
            ),
    );
  }
}
