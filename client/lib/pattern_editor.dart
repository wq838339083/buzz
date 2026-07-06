import 'package:flutter/material.dart';
import 'storage.dart';
import 'vibrator_service.dart';

class PatternEditorPage extends StatefulWidget {
  final List<SavedPattern> patterns;
  const PatternEditorPage({super.key, required this.patterns});
  @override
  State<PatternEditorPage> createState() => _PatternEditorPageState();
}

class _PatternEditorPageState extends State<PatternEditorPage> {
  late List<SavedPattern> _patterns;

  @override
  void initState() {
    super.initState();
    _patterns = List.of(widget.patterns);
  }

  Future<void> _save() async {
    await Storage.savePatterns(_patterns);
    if (!mounted) return;
    Navigator.of(context).pop(_patterns);
  }

  Future<void> _addNew() async {
    final result = await _openEditor(SavedPattern(name: '新样式', pattern: [0, 300]));
    if (result != null) setState(() => _patterns.add(result));
  }

  Future<void> _edit(int i) async {
    final result = await _openEditor(_patterns[i]);
    if (result != null) setState(() => _patterns[i] = result);
  }

  void _delete(int i) {
    setState(() => _patterns.removeAt(i));
  }

  Future<SavedPattern?> _openEditor(SavedPattern p) {
    return Navigator.of(context).push<SavedPattern>(
      MaterialPageRoute(builder: (_) => _SingleEditor(pattern: p)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('震动样式'),
        actions: [
          IconButton(icon: const Icon(Icons.check), onPressed: _save),
        ],
      ),
      body: ListView.separated(
        itemCount: _patterns.length,
        separatorBuilder: (_, __) => const Divider(height: 1),
        itemBuilder: (context, i) {
          final p = _patterns[i];
          return ListTile(
            title: Text(p.name),
            subtitle: Text(_previewText(p.pattern)),
            trailing: Wrap(spacing: 4, children: [
              IconButton(
                icon: const Icon(Icons.play_arrow),
                onPressed: () => VibratorService.play(p.pattern),
              ),
              IconButton(
                icon: const Icon(Icons.edit),
                onPressed: () => _edit(i),
              ),
              IconButton(
                icon: const Icon(Icons.delete_outline),
                onPressed: () => _delete(i),
              ),
            ]),
            onTap: () => _edit(i),
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _addNew,
        child: const Icon(Icons.add),
      ),
    );
  }

  String _previewText(List<int> pattern) {
    if (pattern.isEmpty) return '(空)';
    return pattern.map((e) => '${e}ms').join(' · ');
  }
}

class _SingleEditor extends StatefulWidget {
  final SavedPattern pattern;
  const _SingleEditor({required this.pattern});
  @override
  State<_SingleEditor> createState() => _SingleEditorState();
}

class _SingleEditorState extends State<_SingleEditor> {
  late TextEditingController _nameCtrl;
  late List<int> _segments;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.pattern.name);
    _segments = List.of(widget.pattern.pattern);
    if (_segments.isEmpty) _segments = [0, 300];
  }

  void _addSegment() {
    setState(() {
      _segments.add(150);
      _segments.add(300);
    });
  }

  void _removePair(int index) {
    if (_segments.length <= 2) return;
    final pauseIdx = (index ~/ 2) * 2;
    setState(() {
      _segments.removeAt(pauseIdx);
      if (pauseIdx < _segments.length) _segments.removeAt(pauseIdx);
    });
  }

  void _play() {
    VibratorService.play(_segments);
  }

  void _done() {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('请输入名称')));
      return;
    }
    Navigator.of(context)
        .pop(SavedPattern(name: name, pattern: List.of(_segments)));
  }

  @override
  Widget build(BuildContext context) {
    final pairs = <_Pair>[];
    for (int i = 0; i < _segments.length; i += 2) {
      final pause = _segments[i];
      final vibrate = i + 1 < _segments.length ? _segments[i + 1] : 0;
      pairs.add(_Pair(pause: pause, vibrate: vibrate, index: i));
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('编辑样式'),
        actions: [
          IconButton(icon: const Icon(Icons.play_arrow), onPressed: _play),
          IconButton(icon: const Icon(Icons.check), onPressed: _done),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _nameCtrl,
              decoration: const InputDecoration(
                labelText: '名称',
                border: OutlineInputBorder(),
              ),
            ),
          ),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                '每一段包含"停顿时长"和"震动时长"（毫秒）。点击 ▶ 试听。',
                style: TextStyle(color: Colors.grey),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: pairs.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (context, i) {
                final p = pairs[i];
                return Card(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Row(
                      children: [
                        Text('#${i + 1}',
                            style: const TextStyle(fontWeight: FontWeight.bold)),
                        const SizedBox(width: 12),
                        Expanded(child: _numField(
                          '停顿(ms)',
                          p.pause,
                          (v) => setState(() => _segments[p.index] = v),
                        )),
                        const SizedBox(width: 8),
                        Expanded(child: _numField(
                          '震动(ms)',
                          p.vibrate,
                          (v) => setState(() {
                            if (p.index + 1 < _segments.length) {
                              _segments[p.index + 1] = v;
                            }
                          }),
                        )),
                        IconButton(
                          icon: const Icon(Icons.remove_circle_outline),
                          onPressed: () => _removePair(p.index),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _addSegment,
        icon: const Icon(Icons.add),
        label: const Text('添加一段'),
      ),
    );
  }

  Widget _numField(String label, int value, ValueChanged<int> onChanged) {
    return TextFormField(
      initialValue: value.toString(),
      keyboardType: TextInputType.number,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
        isDense: true,
      ),
      onChanged: (v) {
        final n = int.tryParse(v);
        if (n != null && n >= 0 && n <= 60000) onChanged(n);
      },
    );
  }
}

class _Pair {
  final int pause;
  final int vibrate;
  final int index;
  _Pair({required this.pause, required this.vibrate, required this.index});
}
