import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:web_socket_channel/status.dart' as ws_status;
import 'config.dart';

enum ConnState { disconnected, connecting, connected }

class DeviceInfo {
  final String deviceId;
  final String deviceName;
  final bool online;
  DeviceInfo(this.deviceId, this.deviceName, this.online);
}

typedef BuzzHandler = void Function(BuzzEvent event);

class BuzzEvent {
  final String buzzId;
  final String fromDevice;
  final String fromName;
  final List<int> pattern;
  final int intensity;
  BuzzEvent({
    required this.buzzId,
    required this.fromDevice,
    required this.fromName,
    required this.pattern,
    required this.intensity,
  });
}

class WsService extends ChangeNotifier {
  WebSocketChannel? _ch;
  Timer? _pingTimer;
  Timer? _reconnectTimer;
  int _reconnectDelay = 2;

  ConnState _state = ConnState.disconnected;
  ConnState get state => _state;

  List<DeviceInfo> _devices = [];
  List<DeviceInfo> get devices => _devices;

  String? _selfDeviceId;
  String? get selfDeviceId => _selfDeviceId;

  final Map<String, Set<String>> _pendingAcks = {};

  String? _token;
  String? _deviceId;
  String? _deviceName;

  BuzzHandler? onBuzzReceived;
  void Function(String buzzId, String byDevice, String byName)? onBuzzAck;
  void Function(String buzzId, int delivered)? onBuzzSent;
  void Function()? onAuthRejected;

  bool _disposed = false;
  int _closesWithoutMessage = 0;

  Future<void> connect({
    required String token,
    required String deviceId,
    required String deviceName,
  }) async {
    _token = token;
    _deviceId = deviceId;
    _deviceName = deviceName;
    await _open();
  }

  Future<void> _open() async {
    if (_disposed) return;
    if (_token == null) return;

    _setState(ConnState.connecting);
    final url = AppConfig.wsUrl(
      token: _token!,
      deviceId: _deviceId!,
      deviceName: _deviceName!,
    );

    try {
      final ch = WebSocketChannel.connect(Uri.parse(url));
      _ch = ch;
      bool receivedAnyMessage = false;
      ch.stream.listen(
        (data) {
          receivedAnyMessage = true;
          _closesWithoutMessage = 0;
          _onMessage(data);
        },
        onError: (e) {
          debugPrint('WS error: $e');
          if (!receivedAnyMessage) _closesWithoutMessage++;
          _handleDisconnect();
        },
        onDone: () {
          debugPrint('WS closed (receivedAnyMessage=$receivedAnyMessage, closesWithoutMessage=$_closesWithoutMessage)');
          if (!receivedAnyMessage) {
            _closesWithoutMessage++;
            if (_closesWithoutMessage >= 3) {
              debugPrint('WS: 3 closes without any message — token likely invalid, signaling auth rejection');
              _closesWithoutMessage = 0;
              _disposed = true;
              _pingTimer?.cancel();
              _reconnectTimer?.cancel();
              _setState(ConnState.disconnected);
              onAuthRejected?.call();
              return;
            }
          }
          _handleDisconnect();
        },
        cancelOnError: true,
      );

      _setState(ConnState.connected);
      _reconnectDelay = 2;

      _pingTimer?.cancel();
      _pingTimer = Timer.periodic(const Duration(seconds: 25), (_) {
        _send({'type': 'ping', 'ts': DateTime.now().millisecondsSinceEpoch});
      });
    } catch (e) {
      debugPrint('WS connect failed: $e');
      _handleDisconnect();
    }
  }

  void _onMessage(dynamic raw) {
    Map<String, dynamic> msg;
    try {
      msg = jsonDecode(raw as String) as Map<String, dynamic>;
    } catch (_) {
      return;
    }
    final type = msg['type'];
    switch (type) {
      case 'hello':
        _selfDeviceId = msg['device_id']?.toString();
        notifyListeners();
        break;
      case 'device_list':
        final list = (msg['devices'] as List)
            .map((e) => DeviceInfo(
                  e['device_id'].toString(),
                  (e['device_name'] ?? '').toString(),
                  e['online'] == true,
                ))
            .toList();
        _devices = list;
        notifyListeners();
        break;
      case 'buzz':
        final event = BuzzEvent(
          buzzId: msg['buzz_id'].toString(),
          fromDevice: msg['from_device'].toString(),
          fromName: (msg['from_name'] ?? '').toString(),
          pattern: (msg['pattern'] as List)
              .map((e) => (e as num).toInt())
              .toList(),
          intensity: (msg['intensity'] as num?)?.toInt() ?? 255,
        );
        onBuzzReceived?.call(event);
        sendAck(event.buzzId, event.fromDevice);
        break;
      case 'buzz_ack':
        onBuzzAck?.call(
          msg['buzz_id'].toString(),
          msg['by_device'].toString(),
          (msg['by_name'] ?? '').toString(),
        );
        break;
      case 'buzz_sent':
        onBuzzSent?.call(
          msg['buzz_id'].toString(),
          (msg['delivered'] as num?)?.toInt() ?? 0,
        );
        break;
      case 'pong':
        break;
    }
  }

  void sendBuzz({
    required String buzzId,
    required List<int> pattern,
    List<String>? targets,
    int intensity = 255,
  }) {
    _send({
      'type': 'buzz',
      'buzz_id': buzzId,
      'pattern': pattern,
      if (targets != null) 'targets': targets,
      'intensity': intensity,
    });
  }

  void sendAck(String buzzId, String fromDevice) {
    _send({
      'type': 'buzz_ack',
      'buzz_id': buzzId,
      'from_device': fromDevice,
    });
  }

  void _send(Map<String, dynamic> msg) {
    final ch = _ch;
    if (ch == null || _state != ConnState.connected) return;
    try {
      ch.sink.add(jsonEncode(msg));
    } catch (e) {
      debugPrint('send failed: $e');
    }
  }

  void _handleDisconnect() {
    _pingTimer?.cancel();
    _pingTimer = null;
    try { _ch?.sink.close(ws_status.goingAway); } catch (_) {}
    _ch = null;
    _setState(ConnState.disconnected);
    _scheduleReconnect();
  }

  void _scheduleReconnect() {
    if (_disposed || _token == null) return;
    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(Duration(seconds: _reconnectDelay), _open);
    _reconnectDelay = (_reconnectDelay * 2).clamp(2, 30);
  }

  void _setState(ConnState s) {
    _state = s;
    notifyListeners();
  }

  Future<void> disconnect() async {
    _disposed = true;
    _pingTimer?.cancel();
    _reconnectTimer?.cancel();
    try { await _ch?.sink.close(ws_status.normalClosure); } catch (_) {}
    _ch = null;
    _setState(ConnState.disconnected);
  }

  @override
  void dispose() {
    disconnect();
    super.dispose();
  }
}
