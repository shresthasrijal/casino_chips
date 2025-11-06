// services/websocket_client.dart
import 'dart:convert';
import 'dart:io' show WebSocket;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:web_socket_channel/io.dart';

class WebSocketClient {
  IOWebSocketChannel? _channel;
  String myUsername = '';
  bool _isConnected = false;

  Function(List<String>)? onPlayersUpdate;
  Function(String)? onChatMessage;
  Function(Map<String, int>, int, int)? onStateUpdate;
  Function(Map<String, dynamic>)? onGameStart;

  void connect(String ip, String username, {int port = 8080}) {
    myUsername = username;
    final uri = Uri.parse('ws://$ip:$port');

    disconnect();

    WebSocket.connect(uri.toString())
        .then((webSocket) {
          _channel = IOWebSocketChannel(webSocket);
          _isConnected = true;

          _channel!.sink.add(
            jsonEncode({'type': 'join', 'username': username}),
          );

          _channel!.stream.listen(
            (event) {
              try {
                final data = jsonDecode(event);
                if (data['type'] == 'game_start') {
                  onGameStart?.call(data);
                } else if (data['type'] == 'name_accepted') {
                  myUsername = data['username'];
                } else if (data['type'] == 'players_update') {
                  onPlayersUpdate?.call(List<String>.from(data['players']));
                } else if (data['type'] == 'chat') {
                  onChatMessage?.call('${data['from']}: ${data['text']}');
                } else if (data['type'] == 'state_update') {
                  final chips = Map<String, int>.from(data['chips']);
                  final pot = data['pot'] as int;
                  final turn = data['currentTurn'] as int;
                  onStateUpdate?.call(chips, pot, turn);
                }
              } catch (e) {
                debugPrint('Error decoding WebSocket message: $e');
              }
            },
            onDone: () {
              _isConnected = false;
              debugPrint('WebSocket disconnected');
            },
            onError: (error) {
              _isConnected = false;
              debugPrint('WebSocket error: $error');
            },
          );
        })
        .catchError((error) {
          _isConnected = false;
          debugPrint('Failed to connect to $uri: $error');
        });
  }

  void send(Map<String, dynamic> data) {
    if (_isConnected && _channel != null) {
      _channel!.sink.add(jsonEncode(data));
    } else {
      debugPrint('Cannot send: not connected');
    }
  }

  void disconnect() {
    if (_channel != null) {
      _channel!.sink.close();
      _channel = null;
      _isConnected = false;
    }
  }
}
