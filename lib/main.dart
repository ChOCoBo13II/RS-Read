import 'dart:async';
import 'package:flutter/material.dart';

void main() => runApp(const RsReaderApp());

class RsReaderApp extends StatelessWidget {
  const RsReaderApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'RSReader',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark(useMaterial3: true),
      home: const HomePage(),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _start() {
    final words = _controller.text
        .split(RegExp(r'\s+'))
        .where((w) => w.isNotEmpty)
        .toList();
    if (words.isEmpty) return;
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => ReaderPage(words: words)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('RSReader')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Expanded(
              child: TextField(
                controller: _controller,
                maxLines: null,
                expands: true,
                textAlignVertical: TextAlignVertical.top,
                decoration: const InputDecoration(
                  hintText: 'Incolla qui il testo da leggere',
                  border: OutlineInputBorder(),
                ),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _start,
                child: const Text('Leggi'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class ReaderPage extends StatefulWidget {
  const ReaderPage({super.key, required this.words});

  final List<String> words;

  @override
  State<ReaderPage> createState() => _ReaderPageState();
}

class _ReaderPageState extends State<ReaderPage> {
  int _index = 0;
  double _wpm = 300;
  bool _playing = false;
  Timer? _timer;
  DateTime _due = DateTime.now();

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  int _pivot(String w) {
    final len = w.length;
    final p = len <= 1 ? 0 : len <= 5 ? 1 : len <= 9 ? 2 : len <= 13 ? 3 : 4;
    return p.clamp(0, len - 1);
  }

  void _schedule() {
    if (!_playing) return;
    final w = widget.words[_index];
    var factor = 1.0;
    if (RegExp(r'[.!?…]$').hasMatch(w)) {
      factor = 2.0;
    } else if (RegExp(r'[,;:]$').hasMatch(w)) {
      factor = 1.5;
    }
    if (w.length > 10) factor += 0.3;
    final micros = (60000000 / _wpm * factor).round();
    _due = _due.add(Duration(microseconds: micros));
    var delay = _due.difference(DateTime.now());
    if (delay < const Duration(milliseconds: -250)) {
      _due = DateTime.now();
      delay = Duration.zero;
    } else if (delay.isNegative) {
      delay = Duration.zero;
    }
    _timer = Timer(delay, _tick);
  }

  void _tick() {
    if (_index >= widget.words.length - 1) {
      setState(() => _playing = false);
      return;
    }
    setState(() => _index++);
    _schedule();
  }

  void _toggle() {
    if (_playing) {
      _timer?.cancel();
      setState(() => _playing = false);
    } else {
      if (_index >= widget.words.length - 1) _index = 0;
      setState(() => _playing = true);
      _due = DateTime.now();
      _schedule();
    }
  }

  void _restart() {
    _timer?.cancel();
    setState(() {
      _index = 0;
      _playing = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    const style = TextStyle(
      fontSize: 40,
      fontWeight: FontWeight.w500,
      fontFamily: 'monospace',
    );
    final word = widget.words[_index];
    final p = _pivot(word);
    final total = widget.words.length;
    final remaining = ((total - _index) * 60 / _wpm).round();
    final progress = total > 1 ? _index / (total - 1) : 1.0;

    return Scaffold(
      appBar: AppBar(title: const Text('Lettura')),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      word.substring(0, p),
                      textAlign: TextAlign.right,
                      softWrap: false,
                      overflow: TextOverflow.visible,
                      style: style,
                    ),
                  ),
                  Text(
                    word[p],
                    style: style.copyWith(color: Colors.redAccent),
                  ),
                  Expanded(
                    child: Text(
                      word.substring(p + 1),
                      softWrap: false,
                      overflow: TextOverflow.visible,
                      style: style,
                    ),
                  ),
                ],
              ),
            ),
            LinearProgressIndicator(value: progress),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Text('${_wpm.round()} WPM · restano circa ${remaining}s'),
            ),
            Slider(
              value: _wpm,
              min: 100,
              max: 1000,
              divisions: 90,
              onChanged: (v) => setState(() => _wpm = v),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(
                  iconSize: 48,
                  onPressed: _restart,
                  icon: const Icon(Icons.replay),
                ),
                IconButton(
                  iconSize: 72,
                  onPressed: _toggle,
                  icon: Icon(
                    _playing ? Icons.pause_circle : Icons.play_circle,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
} 
