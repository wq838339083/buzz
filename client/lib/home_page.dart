import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'storage.dart';
import 'ws_service.dart';
import 'vibrator_service.dart';
import 'keepalive.dart';
import 'login_page.dart';
import 'pattern_editor.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});
  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with WidgetsBindingObserver {
  final WsService _ws = WsService();
  List<SavedPattern> _patterns = [];
  SavedPattern? _selected;
  String? _lastStatus;
  final _random = Random();
  final Set<String> _selectedTargets = {};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _init();
  }

  Future<void> _init() async {
    await VibratorService.init();
    await BuzzKeepAlive.init();
    await BuzzKeepAlive.requestPermissions();

    _patterns = await Storage.loadPatterns();
    _selected = _patterns.isNotEmpty ? _patterns.first : null;

    final token = await Storage.getToken();
    if (token == null || token.isEmpty) {
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const LoginPage()),
      );
      return;
    }
    final deviceId = await Storage.getOrCreateDeviceId();
    final deviceName = await Storage.getDeviceName();

    _ws.onBuzzReceived = _onBuzz;
    _ws.onBuzzAck = _onAck;
    _ws.onBuzzSent = _onSent;
    _ws.onAuthRejected = _onAuthRejected;
    _ws.addListener(_onWsChanged);

    await _ws.connect(
      token: token,
      deviceId: deviceId,
      deviceName: deviceName,
    );

    await BuzzKeepAlive.start();

    setState(() {});
  }

  void _onWsChanged() => setState(() {});

  Future<void> _onAuthRejected() async {
    await BuzzKeepAlive.stop();
    await Storage.clearSession();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('登录已失效，请重新登录')),
    );
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const LoginPage()),
    );
  }

  void _onBuzz(BuzzEvent e) {
    VibratorService.play(e.pattern, intensity: e.intensity);
    setState(() {
      _lastStatus = '收到 "${e.fromName}" 的震动';
    });
  }

  void _onAck(String buzzId, String byDevice, String byName) {
    setState(() {
      _lastStatus = '"$byName" 已收到';
    });
  }

  void _onSent(String buzzId, int delivered) {
    setState(() {
      _lastStatus = delivered > 0
          ? '已发送到 $delivered 台设备'
          : '没有其他在线设备';
    });
  }

  Future<void> _sendBuzz() async {
    final p = _selected;
    if (p == null) {
      setState(() => _lastStatus = '请先选择或新建一个震动样式');
      return;
    }
    if (_ws.state != ConnState.connected) {
      setState(() => _lastStatus = '未连接到服务器');
      return;
    }
    VibratorService.play(p.pattern);
    final targets = _selectedTargets.isEmpty
        ? null
        : _selectedTargets.toList();
    final buzzId = '${DateTime.now().millisecondsSinceEpoch}_${_random.nextInt(9999)}';
    _ws.sendBuzz(
      buzzId: buzzId,
      pattern: p.pattern,
      targets: targets,
    );
    setState(() => _lastStatus = '发送中...');
  }

  Future<void> _editPatterns() async {
    final updated = await Navigator.of(context).push<List<SavedPattern>>(
      MaterialPageRoute(
        builder: (_) => PatternEditorPage(patterns: _patterns),
      ),
    );
    if (updated != null) {
      setState(() {
        _patterns = updated;
        if (_selected == null ||
            !_patterns.any((p) => p.name == _selected!.name)) {
          _selected = _patterns.isNotEmpty ? _patterns.first : null;
        }
      });
    }
  }

  Future<void> _logout() async {
    await _ws.disconnect();
    await BuzzKeepAlive.stop();
    await Storage.clearSession();
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const LoginPage()),
    );
  }

  Color _stateColor() {
    switch (_ws.state) {
      case ConnState.connected: return Colors.green;
      case ConnState.connecting: return Colors.orange;
      case ConnState.disconnected: return Colors.red;
    }
  }

  String _stateText() {
    switch (_ws.state) {
      case ConnState.connected: return '已连接';
      case ConnState.connecting: return '连接中';
      case ConnState.disconnected: return '未连接';
    }
  }

  @override
  Widget build(BuildContext context) {
    final others = _ws.devices
        .where((d) => d.deviceId != _ws.selfDeviceId)
        .toList();

    return WithForegroundTask(
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Buzz'),
          actions: [
            IconButton(
              icon: const Icon(Icons.edit),
              tooltip: '编辑震动样式',
              onPressed: _editPatterns,
            ),
            IconButton(
              icon: const Icon(Icons.logout),
              tooltip: '退出登录',
              onPressed: _logout,
            ),
          ],
        ),
        body: SafeArea(
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                color: _stateColor().withValues(alpha: 0.12),
                child: Row(
                  children: [
                    Icon(Icons.circle, color: _stateColor(), size: 12),
                    const SizedBox(width: 8),
                    Text(_stateText()),
                    const Spacer(),
                    Text('其他在线: ${others.length}'),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              _buildDevicesRow(others),
              const Divider(),
              _buildPatternRow(),
              const SizedBox(height: 24),
              Expanded(
                child: Center(
                  child: GestureDetector(
                    onTap: _sendBuzz,
                    child: Container(
                      width: 200,
                      height: 200,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: RadialGradient(
                          colors: [
                            Theme.of(context).colorScheme.primary,
                            Theme.of(context).colorScheme.primary.withValues(alpha: 0.6),
                          ],
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.4),
                            blurRadius: 30,
                            spreadRadius: 4,
                          ),
                        ],
                      ),
                      child: const Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.vibration, size: 72, color: Colors.white),
                            SizedBox(height: 8),
                            Text('震一下',
                                style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  _lastStatus ?? '点击按钮发送震动',
                  style: TextStyle(color: Colors.grey[700]),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDevicesRow(List<DeviceInfo> others) {
    if (others.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(16),
        child: Text('还没有其他在线设备。用同一账号在另一台手机登录试试。',
            style: TextStyle(color: Colors.grey)),
      );
    }
    return SizedBox(
      height: 60,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: others.length + 1,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, i) {
          if (i == 0) {
            final all = _selectedTargets.isEmpty;
            return ChoiceChip(
              label: const Text('全部'),
              selected: all,
              onSelected: (_) => setState(() => _selectedTargets.clear()),
            );
          }
          final d = others[i - 1];
          final selected = _selectedTargets.contains(d.deviceId);
          return FilterChip(
            label: Text(d.deviceName),
            selected: selected,
            onSelected: (v) => setState(() {
              if (v) _selectedTargets.add(d.deviceId);
              else _selectedTargets.remove(d.deviceId);
            }),
          );
        },
      ),
    );
  }

  Widget _buildPatternRow() {
    if (_patterns.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(16),
        child: FilledButton.icon(
          onPressed: _editPatterns,
          icon: const Icon(Icons.add),
          label: const Text('新建一个震动样式'),
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Row(
        children: [
          const Text('样式: '),
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: _patterns.map((p) {
                  final sel = _selected?.name == p.name;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(p.name),
                      selected: sel,
                      onSelected: (_) => setState(() => _selected = p),
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _ws.removeListener(_onWsChanged);
    _ws.dispose();
    super.dispose();
  }
}
