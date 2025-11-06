// services/host_server.dart (fixed: no exclude, host username fixed)
import 'dart:io';
import 'dart:convert';

class HostServer {
  HttpServer? _server;
  final List<WebSocket> _clients = [];
  final List<String> players = ['Host']; // Host always "Host"
  final Map<WebSocket, String> clientUsernames = {};

  Function(String)? onLog;
  Function(List<String>)? onPlayersUpdate;
  Function(String)? onChatMessage;
  Function(Map<String, dynamic>, WebSocket)? onCustomMessage;

  Future<void> startServer({
    int port = 8080,
    Function(String)? onLog,
    Function(List<String>)? onPlayersUpdate,
    Function(String)? onChatMessage,
    Function(Map<String, dynamic>, WebSocket)? onCustomMessage,
  }) async {
    this.onLog = onLog;
    this.onPlayersUpdate = onPlayersUpdate;
    this.onChatMessage = onChatMessage;
    this.onCustomMessage = onCustomMessage;

    onPlayersUpdate?.call(players);

    _server = await HttpServer.bind(InternetAddress.anyIPv4, port);
    onLog?.call('Server on ws://${_server!.address.address}:$port');

    _server!.listen((req) async {
      if (WebSocketTransformer.isUpgradeRequest(req)) {
        final socket = await WebSocketTransformer.upgrade(req);
        _clients.add(socket);
        onLog?.call('Client connected (${_clients.length})');

        socket.listen(
          (message) {
            final data = jsonDecode(message);
            if (data['type'] == 'join') {
              var username = data['username'];
              if (players.contains(username)) {
                int i = 2;
                while (players.contains('$username ($i)')) {
                  i++;
                }
                username = '$username ($i)';
              }
              clientUsernames[socket] = username;
              players.add(username);

              // UPDATE HOST FIRST
              onPlayersUpdate?.call(players);

              // THEN TELL EVERYONE (INCLUDING CLIENT)
              broadcast({'type': 'players_update', 'players': players});

              // SEND NAME BACK TO CLIENT
              socket.add(
                jsonEncode({'type': 'name_accepted', 'username': username}),
              );

              onLog?.call('Player joined: $username');
            } else if (data['type'] == 'chat') {
              final from = clientUsernames[socket] ?? 'Unknown';
              final text = data['text'];
              onChatMessage?.call('$from: $text');
              broadcast({'type': 'chat', 'from': from, 'text': text});
            } else {
              onCustomMessage?.call(data, socket);
            }
          },
          onDone: () {
            final username = clientUsernames.remove(socket);
            if (username != null) {
              players.remove(username);
              onPlayersUpdate?.call(players); // UPDATE HOST
              broadcast({
                'type': 'players_update',
                'players': players,
              }); // UPDATE ALL
              onLog?.call('Player left: $username');
            }
            _clients.remove(socket);
          },
        );
      }
    });
  }

  void broadcast(Map<String, dynamic> data) {
    final json = jsonEncode(data);
    final deadClients = <WebSocket>[];

    for (var c in _clients) {
      try {
        // Check if already closed? Not directly possible → just try
        c.add(json);
      } catch (e) {
        // Socket is closed or broken
        deadClients.add(c);
      }
    }

    // Remove dead clients
    for (var dead in deadClients) {
      _clients.remove(dead);
      clientUsernames.remove(dead);
    }

    // Notify host via callbacks (safe)
    if (data['type'] == 'players_update') {
      onPlayersUpdate?.call(List<String>.from(data['players']));
    } else if (data['type'] == 'chat') {
      onChatMessage?.call('${data['from']}: ${data['text']}');
    }
  }

  void stopServer() {
    for (var c in _clients) {
      c.close();
    }
    _server?.close();
  }
}
