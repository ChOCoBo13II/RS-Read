import 'dart:async';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
  String _savedText = '';
  int _savedIndex = 0;

  @override
  void initState() {
    super.initState();
    _load(withText: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _load({bool withText = false}) async {
    final p = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _savedText = p.getString('text') ?? '';
      _savedIndex = p.getInt('index') ?? 0;
      if (withText) _controller.text = _savedText;
    });
  }

  Future<void> _start({required bool resume}) async {
    final text = _controller.text;
    final words =
        text.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();
    if (words.isEmpty) return;
    final start = resume && text == _savedText ? _savedIndex : 0;
    final p = await SharedPreferences.getInstance();
    await p.setString('text', text);
    await p.setInt('index', start);
    if (!mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ReaderPage(words: words, startIndex: start),
      ),
    );
    _load();
  }

  @override
  Widget build(BuildContext context) {
    final canResume = _savedIndex > 0 && _controller.text == _savedText;
    return Scaffold(
      appBar: AppBar(title: const Text('RSReader')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Expanded(
              child: TextField(
                controller: _controller,
                onChanged: (_) => setState(() {}),
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
            if (canResume) ...[
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () => _start(resume: true),
                  child: Text('Continua da parola ${_savedIndex + 1}'),
                ),
              ),
              const SizedBox(height: 8),
            ],
            SizedBox(
              width: double.infinity,
              child: canResume
                  ? OutlinedButton(
                      onPressed: () => _start(resume: false),
                      child: const Text("Leggi dall'inizio"),
                    )
                  : FilledButton(
                      onPressed: () => _start(resume: false),
                      child: const Text("Leggi dall'inizio"),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class ReaderPage extends StatefulWidget {
  const ReaderPage({super.key, required this.words, this.startIndex = 0});

  final List<String> words;
  final int startIndex;

  @override
  State<ReaderPage> createState() => _ReaderPageState();
}

class _ReaderPageState extends State<ReaderPage> with WidgetsBindingObserver {
  int _index = 0;
  double _wpm = 300;
  bool _playing = false;
  Timer? _timer;
  DateTime _due = DateTime.now();

  @override
  void initState() {
    super.initState();
    _index = widget.startIndex.clamp(0, widget.words.length - 1);
    WidgetsBinding.instance.addObserver(this);
    SharedPreferences.getInstance().then((p) {
      final saved = p.getDouble('wpm');
      if (saved != null && mounted) setState(() => _wpm = saved);
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
    _save();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      _timer?.cancel();
      setState(() => _playing = false);
      _save();
    }
  }

  void _save() {
    final i = _index;
    SharedPreferences.getInstance().then((p) => p.setInt('index', i));
  }

  int _pivot(String w) {
    final len = w.length;
    final p = len <= 1 ? 0 : len <= 5 ? 1 : len <= 9 ? 2 : (len - 1) ~/ 2;
    return p.clamp(0, len - 1);
  }

  bool _endsSentence(String w) => RegExp(r'[.!?…]["”»)]*$').hasMatch(w);

  void _schedule() {
    if (!_playing) return;
    final w = widget.words[_index];
    var factor = 1.0;
    if (_endsSentence(w)) {
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
      _save();
      return;
    }
    setState(() => _index++);
    if (_index % 10 == 0) _save();
    _schedule();
  }

  void _toggle() {
    if (_playing) {
      _timer?.cancel();
      setState(() => _playing = false);
      _save();
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
    _save();
  }

  void _goTo(int i) {
    final last = widget.words.length - 1;
    final target = i.clamp(0, last);
    _timer?.cancel();
    setState(() => _index = target);
    if (_playing) {
      _due = DateTime.now();
      _schedule();
    }
    _save();
  }

  int _sentenceStart(int from) {
    var i = from;
    while (i > 0 && !_endsSentence(widget.words[i - 1])) {
      i--;
    }
    return i;
  }

  void _sentenceBack() {
    var target = _sentenceStart(_index);
    if (target == _index && _index > 0) {
      target = _sentenceStart(_index - 1);
    }
    _goTo(target);
  }

  void _sentenceForward() {
    final last = widget.words.length - 1;
    var i = _index;
    while (i < last && !_endsSentence(widget.words[i])) {
      i++;
    }
    _goTo(i + 1);
  }

  String _fmt(int s) {
    final m = s ~/ 60;
    final r = s % 60;
    return '$m:${r.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final word = widget.words[_index];
    final p = _pivot(word);
    final side = p > word.length - 1 - p ? p : word.length - 1 - p;
    final half = MediaQuery.of(context).size.width / 2 - 16;
    final fit = half / ((side + 0.5) * 0.65);
    final style = TextStyle(
      fontSize: fit < 40.0 ? fit : 40.0,
      fontWeight: FontWeight.w500,
      fontFamily: 'monospace',
    );
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
              child: Text(
                '${_wpm.round()} WPM · restano circa ${_fmt(remaining)}',
              ),
            ),
            Slider(
              value: _wpm,
              min: 100,
              max: 1000,
              divisions: 90,
              onChanged: (v) => setState(() => _wpm = v),
              onChangeEnd: (v) => SharedPreferences.getInstance()
                  .then((prefs) => prefs.setDouble('wpm', v)),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(
                  iconSize: 32,
                  tooltip: 'Dall’inizio',
                  onPressed: _restart,
                  icon: const Icon(Icons.replay),
                ),
                IconButton(
                  iconSize: 32,
                  tooltip: 'Frase indietro',
                  onPressed: _sentenceBack,
                  icon: const Icon(Icons.keyboard_double_arrow_left),
                ),
                IconButton(
                  iconSize: 32,
                  tooltip: 'Parola indietro',
                  onPressed: () => _goTo(_index - 1),
                  icon: const Icon(Icons.chevron_left),
                ),
                IconButton(
                  iconSize: 64,
                  onPressed: _toggle,
                  icon: Icon(
                    _playing ? Icons.pause_circle : Icons.play_circle,
                  ),
                ),
                IconButton(
                  iconSize: 32,
                  tooltip: 'Parola avanti',
                  onPressed: () => _goTo(_index + 1),
                  icon: const Icon(Icons.chevron_right),
                ),
                IconButton(
                  iconSize: 32,
                  tooltip: 'Frase avanti',
                  onPressed: _sentenceForward,
                  icon: const Icon(Icons.keyboard_double_arrow_right),
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
