import 'package:flutter/material.dart';
import 'api.dart';
import 'storage.dart';
import 'home_page.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});
  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _usernameCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _deviceNameCtrl = TextEditingController();
  bool _loading = false;
  bool _isRegister = false;

  @override
  void initState() {
    super.initState();
    Storage.getDeviceName().then((v) => _deviceNameCtrl.text = v);
  }

  Future<void> _submit() async {
    final u = _usernameCtrl.text.trim();
    final p = _passwordCtrl.text;
    final dn = _deviceNameCtrl.text.trim();
    if (u.isEmpty || p.isEmpty) {
      _snack('请输入账号和密码');
      return;
    }
    if (dn.isEmpty) {
      _snack('请输入设备名');
      return;
    }
    setState(() => _loading = true);
    try {
      final res = _isRegister
          ? await Api.register(u, p)
          : await Api.login(u, p);
      await Storage.saveSession(
        token: res['token'] as String,
        username: res['username'] as String,
      );
      await Storage.setDeviceName(dn);
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const HomePage()),
      );
    } catch (e) {
      _snack('${_isRegister ? "注册" : "登录"}失败: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _snack(String s) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(s)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Buzz')),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 24),
              const Icon(Icons.vibration, size: 80),
              const SizedBox(height: 24),
              Text(
                _isRegister ? '注册' : '登录',
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 24),
              TextField(
                controller: _usernameCtrl,
                decoration: const InputDecoration(
                  labelText: '用户名',
                  border: OutlineInputBorder(),
                ),
                enabled: !_loading,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _passwordCtrl,
                decoration: const InputDecoration(
                  labelText: '密码',
                  border: OutlineInputBorder(),
                ),
                obscureText: true,
                enabled: !_loading,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _deviceNameCtrl,
                decoration: const InputDecoration(
                  labelText: '本机名称（其他设备看到的名字）',
                  border: OutlineInputBorder(),
                ),
                enabled: !_loading,
              ),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: _loading ? null : _submit,
                child: _loading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(_isRegister ? '注册并登录' : '登录'),
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: _loading
                    ? null
                    : () => setState(() => _isRegister = !_isRegister),
                child: Text(_isRegister ? '已有账号？去登录' : '没有账号？去注册'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
