import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

void main() => runApp(const RsReaderApp());

class ParsedText {
  const ParsedText(this.words, this.starts);

  final List<String> words;
  final List<int> starts;
}

ParsedText parseText(String text) {
  final hasBlank = RegExp(r'\n\s*\n').hasMatch(text);
  final parts = hasBlank ? text.split(RegExp(r'\n\s*\n')) : text.split('\n');
  final words = <String>[];
  final starts = <int>[];
  for (final part in parts) {
    final w = part.split(RegExp(r'\s+')).where((x) => x.isNotEmpty).toList();
    if (w.isEmpty) continue;
    starts.add(words.length);
    words.addAll(w);
  }
  return ParsedText(words, starts);
}

class ReadSettings {
  double comma = 0.5;
  double period = 1.0;
  double paragraph = 2.0;
  bool gradual = false;
  bool keepAwake = true;

  static Future<ReadSettings> load() async {
    final p = await SharedPreferences.getInstance();
    final s = ReadSettings();
    s.comma = p.getDouble('pauseComma') ?? s.comma;
    s.period = p.getDouble('pausePeriod') ?? s.period;
    s.paragraph = p.getDouble('pauseParagraph') ?? s.paragraph;
    s.gradual = p.getBool('gradual') ?? s.gradual;
    s.keepAwake = p.getBool('keepAwake') ?? s.keepAwake;
    return s;
  }

  Future<void> save() async {
    final p = await SharedPreferences.getInstance();
    await p.setDouble('pauseComma', comma);
    await p.setDouble('pausePeriod', period);
    await p.setDouble('pauseParagraph', paragraph);
    await p.setBool('gradual', gradual);
    await p.setBool('keepAwake', keepAwake);
  }
}

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
    final parsed = parseText(text);
    if (parsed.words.isEmpty) return;
    final start = resume && text == _savedText ? _savedIndex : 0;
    final p = await SharedPreferences.getInstance();
    await p.setString('text', text);
    await p.setInt('index', start);
    if (!mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ReaderPage(
          words: parsed.words,
          starts: parsed.starts,
          startIndex: start,
        ),
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

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  ReadSettings? _s;

  @override
  void initState() {
    super.initState();
    ReadSettings.load().then((s) {
      if (mounted) setState(() => _s = s);
    });
  }

  Widget _pause(
    String label,
    double value,
    ValueChanged<double> onChanged,
    ReadSettings s,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: Text('$label: ${value.toStringAsFixed(2)} parole'),
        ),
        Slider(
          value: value,
          min: 0,
          max: 3,
          divisions: 12,
          onChanged: (v) => setState(() => onChanged(v)),
          onChangeEnd: (_) => s.save(),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = _s;
    return Scaffold(
      appBar: AppBar(title: const Text('Impostazioni')),
      body: s == null
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              children: [
                const Padding(
                  padding: EdgeInsets.fromLTRB(16, 16, 16, 0),
                  child: Text('Pause extra, in durate di una parola'),
                ),
                _pause('Dopo la virgola', s.comma, (v) => s.comma = v, s),
                _pause('Dopo il punto', s.period, (v) => s.period = v, s),
                _pause(
                  'Dopo il paragrafo',
                  s.paragraph,
                  (v) => s.paragraph = v,
                  s,
                ),
                SwitchListTile(
                  title: const Text('Avvio graduale'),
                  subtitle: const Text(
                    'Parte a metà velocità e sale in 10 parole',
                  ),
                  value: s.gradual,
                  onChanged: (v) {
                    setState(() => s.gradual = v);
                    s.save();
                  },
                ),
                SwitchListTile(
                  title: const Text('Schermo sempre acceso'),
                  subtitle: const Text('Durante la lettura'),
                  value: s.keepAwake,
                  onChanged: (v) {
                    setState(() => s.keepAwake = v);
                    s.save();
                  },
                ),
              ],
            ),
    );
  }
}

class ReaderPage extends StatefulWidget {
  const ReaderPage({
    super.key,
    required this.words,
    required this.starts,
    this.startIndex = 0,
  });

  final List<String> words;
  final List<int> starts;
  final int startIndex;

  @override
  State<ReaderPage> createState() => _ReaderPageState();
}

class _ReaderPageState extends State<ReaderPage> with WidgetsBindingObserver {
  int _index = 0;
  double _wpm = 300;
  bool _playing = false;
  bool _fullscreen = false;
  int _sinceStart = 0;
  ReadSettings _settings = ReadSettings();
  Timer? _timer;
  DateTime _due = DateTime.now();

  late final Set<int> _paraEnds =
      widget.starts.where((s) => s > 0).map((s) => s - 1).toSet();

  @override
  void initState() {
    super.initState();
    _index = widget.startIndex.clamp(0, widget.words.length - 1);
    WidgetsBinding.instance.addObserver(this);
    SharedPreferences.getInstance().then((p) {
      final saved = p.getDouble('wpm');
      if (saved != null && mounted) setState(() => _wpm = saved);
    });
    _loadSettings();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
    WakelockPlus.disable();
    if (_fullscreen) {
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    }
    _save();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      _timer?.cancel();
      setState(() => _playing = false);
      _applyWakelock();
      _save();
    }
  }

  Future<void> _loadSettings() async {
    final s = await ReadSettings.load();
    if (!mounted) return;
    setState(() => _settings = s);
    _applyWakelock();
  }

  void _applyWakelock() {
    if (_playing && _settings.keepAwake) {
      WakelockPlus.enable();
    } else {
      WakelockPlus.disable();
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
    if (_paraEnds.contains(_index)) {
      factor += _settings.paragraph;
    } else if (_endsSentence(w)) {
      factor += _settings.period;
    } else if (RegExp(r'[,;:]$').hasMatch(w)) {
      factor += _settings.comma;
    }
    if (w.length > 10) factor += 0.3;
    final steps = _sinceStart < 10 ? _sinceStart : 10;
    final ramp = _settings.gradual ? 0.5 + 0.05 * steps : 1.0;
    final micros = (60000000 / (_wpm * ramp) * factor).round();
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
      _applyWakelock();
      _save();
      return;
    }
    setState(() => _index++);
    _sinceStart++;
    if (_index % 10 == 0) _save();
    _schedule();
  }

  void _toggle() {
    if (_playing) {
      _timer?.cancel();
      setState(() => _playing = false);
      _applyWakelock();
      _save();
    } else {
      if (_index >= widget.words.length - 1) _index = 0;
      setState(() => _playing = true);
      _applyWakelock();
      _sinceStart = 0;
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
    _applyWakelock();
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

  int _paraStart(int i) {
    var s = 0;
    for (final x in widget.starts) {
      if (x <= i) {
        s = x;
      } else {
        break;
      }
    }
    return s;
  }

  void _paragraphBack() {
    var target = _paraStart(_index);
    if (target == _index && _index > 0) {
      target = _paraStart(_index - 1);
    }
    _goTo(target);
  }

  void _paragraphForward() {
    for (final x in widget.starts) {
      if (x > _index) {
        _goTo(x);
        return;
      }
    }
    _goTo(widget.words.length - 1);
  }

  void _toggleFullscreen() {
    setState(() => _fullscreen = !_fullscreen);
    SystemChrome.setEnabledSystemUIMode(
      _fullscreen ? SystemUiMode.immersiveSticky : SystemUiMode.edgeToEdge,
    );
    if (_fullscreen) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Tocca la parola per uscire dallo schermo intero'),
        ),
      );
    }
  }

  Future<void> _openSettings() async {
    _timer?.cancel();
    setState(() => _playing = false);
    _applyWakelock();
    _save();
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const SettingsPage()),
    );
    _loadSettings();
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
      appBar: _fullscreen
          ? null
          : AppBar(
              title: const Text('Lettura'),
              actions: [
                IconButton(
                  tooltip: 'Dall’inizio',
                  onPressed: _restart,
                  icon: const Icon(Icons.replay),
                ),
                IconButton(
                  tooltip: 'Schermo intero',
                  onPressed: _toggleFullscreen,
                  icon: const Icon(Icons.fullscreen),
                ),
                IconButton(
                  tooltip: 'Impostazioni',
                  onPressed: _openSettings,
                  icon: const Icon(Icons.settings),
                ),
              ],
            ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: _fullscreen ? _toggleFullscreen : null,
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
            ),
            LinearProgressIndicator(value: progress),
            if (!_fullscreen) ...[
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
            ],
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    iconSize: 32,
                    tooltip: 'Paragrafo indietro',
                    onPressed: _paragraphBack,
                    icon: const Icon(Icons.skip_previous),
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
                  IconButton(
                    iconSize: 32,
                    tooltip: 'Paragrafo avanti',
                    onPressed: _paragraphForward,
                    icon: const Icon(Icons.skip_next),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}
