import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_soloud/flutter_soloud.dart' show SoLoud;
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
 
/// Suono del ticchettio. Il motore audio parte solo quando serve e, se
/// qualcosa va storto, la lettura continua senza suono.
class TickPlayer {
  TickPlayer._();
 
  static final TickPlayer instance = TickPlayer._();
 
  // Dimensione del buffer audio: più piccolo = meno ritardo del suono,
  // ma su telefoni lenti può scricchiolare. Se serve, si cambia qui.
  static const int _soundBuffer = 1024;
 
  Future<void>? _init;
  void Function(double volume)? _playFn;
 
  Future<void> ensureReady() => _init ??= _doInit();
 
  Future<void> _doInit() async {
    try {
      await SoLoud.instance.init(bufferSize: _soundBuffer);
      final source = await SoLoud.instance.loadMem(
        'tick.wav',
        base64Decode(_tickWavBase64),
      );
      _playFn = (v) => SoLoud.instance.play(source, volume: v);
    } catch (_) {
      _playFn = null;
    }
  }
 
  void play(double volume) {
    final f = _playFn;
    if (f == null) return;
    try {
      f(volume);
    } catch (_) {
      _playFn = null;
    }
  }
}
 
class ReadSettings {
  double comma = 0.5;
  double period = 1.0;
  double paragraph = 2.0;
  bool gradual = false;
  bool keepAwake = true;
  bool showFullscreenHint = true;
  bool tick = true;
  double tickVolume = 0.6;
  double zoneOpacity = 0.0;
  double zoneVertical = 0.5;
  double zoneMargin = 0.0;
  bool zoneSeparate = false;
  double zoneLeftW = 3.0;
  double zoneLeftH = 5.0;
  bool zoneLeftAbove = false;
  double zoneRightW = 3.0;
  double zoneRightH = 5.0;
  bool zoneRightAbove = false;
 
  static Future<ReadSettings> load() async {
    final p = await SharedPreferences.getInstance();
    final s = ReadSettings();
    s.comma = p.getDouble('pauseComma') ?? s.comma;
    s.period = p.getDouble('pausePeriod') ?? s.period;
    s.paragraph = p.getDouble('pauseParagraph') ?? s.paragraph;
    s.gradual = p.getBool('gradual') ?? s.gradual;
    s.keepAwake = p.getBool('keepAwake') ?? s.keepAwake;
    s.showFullscreenHint = !(p.getBool('hideFullscreenHint') ?? false);
    s.tick = p.getBool('tick') ?? s.tick;
    s.tickVolume = p.getDouble('tickVolume') ?? s.tickVolume;
    s.zoneOpacity = p.getDouble('zoneOpacity') ?? s.zoneOpacity;
    s.zoneVertical = p.getDouble('zoneVertical') ?? s.zoneVertical;
    s.zoneMargin = p.getDouble('zoneMargin') ?? s.zoneMargin;
    s.zoneSeparate = p.getBool('zoneSeparate') ?? s.zoneSeparate;
    s.zoneLeftW = p.getDouble('zoneLeftW') ?? s.zoneLeftW;
    s.zoneLeftH = p.getDouble('zoneLeftH') ?? s.zoneLeftH;
    s.zoneLeftAbove = p.getBool('zoneLeftAbove') ?? s.zoneLeftAbove;
    s.zoneRightW = p.getDouble('zoneRightW') ?? s.zoneRightW;
    s.zoneRightH = p.getDouble('zoneRightH') ?? s.zoneRightH;
    s.zoneRightAbove = p.getBool('zoneRightAbove') ?? s.zoneRightAbove;
    return s;
  }
 
  Future<void> save() async {
    final p = await SharedPreferences.getInstance();
    await p.setDouble('pauseComma', comma);
    await p.setDouble('pausePeriod', period);
    await p.setDouble('pauseParagraph', paragraph);
    await p.setBool('gradual', gradual);
    await p.setBool('keepAwake', keepAwake);
    await p.setBool('hideFullscreenHint', !showFullscreenHint);
    await p.setBool('tick', tick);
    await p.setDouble('tickVolume', tickVolume);
    await p.setDouble('zoneOpacity', zoneOpacity);
    await p.setDouble('zoneVertical', zoneVertical);
    await p.setDouble('zoneMargin', zoneMargin);
    await p.setBool('zoneSeparate', zoneSeparate);
    await p.setDouble('zoneLeftW', zoneLeftW);
    await p.setDouble('zoneLeftH', zoneLeftH);
    await p.setBool('zoneLeftAbove', zoneLeftAbove);
    await p.setDouble('zoneRightW', zoneRightW);
    await p.setDouble('zoneRightH', zoneRightH);
    await p.setBool('zoneRightAbove', zoneRightAbove);
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
 
  Widget _slider({
    required String text,
    required double value,
    required double max,
    required int divisions,
    required ValueChanged<double> onChanged,
    required ReadSettings s,
    double min = 0,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: Text(text),
        ),
        Slider(
          value: value,
          min: min,
          max: max,
          divisions: divisions,
          onChanged: (v) => setState(() => onChanged(v)),
          onChangeEnd: (_) => s.save(),
        ),
      ],
    );
  }
 
  Widget _title(String text) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
      child: Text(
        text,
        style: const TextStyle(fontWeight: FontWeight.bold),
      ),
    );
  }
 
  List<Widget> _zoneControls({
    required String name,
    required double w,
    required double h,
    required bool above,
    required ValueChanged<double> onW,
    required ValueChanged<double> onH,
    required ValueChanged<bool> onAbove,
    required ReadSettings s,
  }) {
    return [
      _slider(
        text: 'Larghezza$name: ${w.toStringAsFixed(1)} cm',
        value: w,
        min: 0.5,
        max: 8,
        divisions: 15,
        onChanged: onW,
        s: s,
      ),
      _slider(
        text: 'Altezza$name: ${h.toStringAsFixed(1)} cm',
        value: h,
        min: 1,
        max: 12,
        divisions: 22,
        onChanged: onH,
        s: s,
      ),
      SwitchListTile(
        title: Text('Zona$name sopra l’area della parola'),
        subtitle: const Text('Dove si sovrappongono, vince la pausa'),
        value: above,
        onChanged: (v) {
          setState(() => onAbove(v));
          s.save();
        },
      ),
    ];
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
                _title('Pause extra, in durate di una parola'),
                _slider(
                  text: 'Dopo la virgola: ${s.comma.toStringAsFixed(2)} parole',
                  value: s.comma,
                  max: 3,
                  divisions: 12,
                  onChanged: (v) => s.comma = v,
                  s: s,
                ),
                _slider(
                  text: 'Dopo il punto: ${s.period.toStringAsFixed(2)} parole',
                  value: s.period,
                  max: 3,
                  divisions: 12,
                  onChanged: (v) => s.period = v,
                  s: s,
                ),
                _slider(
                  text: 'Dopo il paragrafo: '
                      '${s.paragraph.toStringAsFixed(2)} parole',
                  value: s.paragraph,
                  max: 3,
                  divisions: 12,
                  onChanged: (v) => s.paragraph = v,
                  s: s,
                ),
                _title('Zone di pausa (schermo intero)'),
                _slider(
                  text: 'Opacità: ${(s.zoneOpacity * 100).round()}%',
                  value: s.zoneOpacity,
                  max: 1,
                  divisions: 20,
                  onChanged: (v) => s.zoneOpacity = v,
                  s: s,
                ),
                _slider(
                  text: 'Posizione verticale: '
                      '${(s.zoneVertical * 100).round()}% (50% = centro)',
                  value: s.zoneVertical,
                  max: 1,
                  divisions: 20,
                  onChanged: (v) => s.zoneVertical = v,
                  s: s,
                ),
                _slider(
                  text: 'Distanza dal bordo: '
                      '${s.zoneMargin.toStringAsFixed(2)} cm',
                  value: s.zoneMargin,
                  max: 2,
                  divisions: 8,
                  onChanged: (v) => s.zoneMargin = v,
                  s: s,
                ),
                SwitchListTile(
                  title: const Text('Regola le due zone separatamente'),
                  subtitle: const Text('Dimensioni e sovrapposizione'),
                  value: s.zoneSeparate,
                  onChanged: (v) {
                    setState(() {
                      s.zoneSeparate = v;
                      if (v) {
                        s.zoneRightW = s.zoneLeftW;
                        s.zoneRightH = s.zoneLeftH;
                        s.zoneRightAbove = s.zoneLeftAbove;
                      }
                    });
                    s.save();
                  },
                ),
                ..._zoneControls(
                  name: s.zoneSeparate ? ' sinistra' : '',
                  w: s.zoneLeftW,
                  h: s.zoneLeftH,
                  above: s.zoneLeftAbove,
                  onW: (v) => s.zoneLeftW = v,
                  onH: (v) => s.zoneLeftH = v,
                  onAbove: (v) => s.zoneLeftAbove = v,
                  s: s,
                ),
                if (s.zoneSeparate)
                  ..._zoneControls(
                    name: ' destra',
                    w: s.zoneRightW,
                    h: s.zoneRightH,
                    above: s.zoneRightAbove,
                    onW: (v) => s.zoneRightW = v,
                    onH: (v) => s.zoneRightH = v,
                    onAbove: (v) => s.zoneRightAbove = v,
                    s: s,
                  ),
                _title('Lettura'),
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
                SwitchListTile(
                  title: const Text('Suggerimento schermo intero'),
                  subtitle: const Text('Il banner che spiega come usarlo'),
                  value: s.showFullscreenHint,
                  onChanged: (v) {
                    setState(() => s.showFullscreenHint = v);
                    s.save();
                  },
                ),
                _title('Suono'),
                SwitchListTile(
                  title: const Text('Ticchettio a ogni parola'),
                  subtitle: const Text('Segue la velocità di lettura'),
                  value: s.tick,
                  onChanged: (v) {
                    setState(() => s.tick = v);
                    s.save();
                  },
                ),
                _slider(
                  text: 'Volume del tic: ${(s.tickVolume * 100).round()}%',
                  value: s.tickVolume,
                  max: 1,
                  divisions: 20,
                  onChanged: (v) => s.tickVolume = v,
                  s: s,
                ),
                ListTile(
                  title: const Text('Prova il suono'),
                  trailing: const Icon(Icons.volume_up),
                  onTap: () async {
                    await TickPlayer.instance.ensureReady();
                    TickPlayer.instance.play(s.tickVolume);
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
  static const double _dpPerCm = 63.0;
 
  int _index = 0;
  double _wpm = 300;
  bool _playing = false;
  bool _fullscreen = false;
  bool _seekWasPlaying = false;
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
    if (s.tick) unawaited(TickPlayer.instance.ensureReady());
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
 
  // Il tic parte dopo che il fotogramma con la nuova parola è stato
  // costruito, così suono e parola restano agganciati alla stessa cadenza.
  void _playTick() {
    if (!_settings.tick) return;
    final volume = _settings.tickVolume;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_playing) return;
      TickPlayer.instance.play(volume);
    });
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
    _playTick();
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
      _playTick();
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
      _playTick();
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
      _showFullscreenHint();
    } else {
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
    }
  }
 
  void _showFullscreenHint() {
    if (!_settings.showFullscreenHint) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: const Color(0xFF0D3E69),
        duration: const Duration(seconds: 6),
        content: const Text(
          'Tocca i lati per la pausa, la parola per uscire',
          style: TextStyle(color: Colors.white),
        ),
        action: SnackBarAction(
          label: 'Non mostrare più',
          textColor: Colors.redAccent,
          onPressed: () {
            _settings.showFullscreenHint = false;
            _settings.save();
          },
        ),
      ),
    );
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
 
    final probe = TextPainter(
      text: TextSpan(text: 'M', style: style),
      textDirection: TextDirection.ltr,
    )..layout();
    final cw = probe.width;
    final lineH = probe.height;
    probe.dispose();
    final dx = (word.length - 1 - 2 * p) * cw / 2;
    final hitW = word.length * cw + 24;
    final hitH = lineH + 24;
 
    final sep = _settings.zoneSeparate;
    final leftW = _settings.zoneLeftW;
    final leftH = _settings.zoneLeftH;
    final leftAbove = _settings.zoneLeftAbove;
    final rightW = sep ? _settings.zoneRightW : leftW;
    final rightH = sep ? _settings.zoneRightH : leftH;
    final rightAbove = sep ? _settings.zoneRightAbove : leftAbove;
 
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
        top: !_fullscreen,
        bottom: !_fullscreen,
        child: Column(
          children: [
            Expanded(
              child: LayoutBuilder(
                builder: (context, c) {
                  final areaW = c.maxWidth;
                  final areaH = c.maxHeight;
                  final margin = _settings.zoneMargin * _dpPerCm;
                  final alpha = (_settings.zoneOpacity * 255).round();
 
                  Widget zone({
                    required bool left,
                    required double wCm,
                    required double hCm,
                  }) {
                    final zw = math.max(
                      0.0,
                      math.min(wCm * _dpPerCm, areaW - margin),
                    );
                    final zh = math.min(hCm * _dpPerCm, areaH);
                    var top = _settings.zoneVertical * areaH - zh / 2;
                    if (top > areaH - zh) top = areaH - zh;
                    if (top < 0) top = 0;
                    return Positioned(
                      top: top,
                      width: zw,
                      height: zh,
                      left: left ? margin : null,
                      right: left ? null : margin,
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: _toggle,
                        child: ColoredBox(
                          color: Colors.white.withAlpha(alpha),
                        ),
                      ),
                    );
                  }
 
                  return Stack(
                    fit: StackFit.expand,
                    children: [
                      Row(
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
                      if (_fullscreen) ...[
                        if (!leftAbove)
                          zone(left: true, wCm: leftW, hCm: leftH),
                        if (!rightAbove)
                          zone(left: false, wCm: rightW, hCm: rightH),
                        Center(
                          child: Transform.translate(
                            offset: Offset(dx, 0),
                            child: GestureDetector(
                              behavior: HitTestBehavior.opaque,
                              onTap: _toggleFullscreen,
                              child: SizedBox(width: hitW, height: hitH),
                            ),
                          ),
                        ),
                        if (leftAbove) zone(left: true, wCm: leftW, hCm: leftH),
                        if (rightAbove)
                          zone(left: false, wCm: rightW, hCm: rightH),
                      ],
                    ],
                  );
                },
              ),
            ),
            if (!_fullscreen) ...[
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
                child: Text(
                  'Parola ${_index + 1} di $total · '
                  'restano circa ${_fmt(remaining)}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
              Slider(
                value: _index.toDouble(),
                min: 0,
                max: total > 1 ? (total - 1).toDouble() : 1.0,
                onChangeStart: (_) {
                  _seekWasPlaying = _playing;
                  _timer?.cancel();
                  setState(() => _playing = false);
                },
                onChanged: (v) {
                  setState(() => _index = v.round().clamp(0, total - 1));
                },
                onChangeEnd: (_) {
                  _save();
                  if (_seekWasPlaying) {
                    setState(() => _playing = true);
                    _playTick();
                    _due = DateTime.now();
                    _schedule();
                  }
                },
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
                child: Text(
                  'Velocità: ${_wpm.round()} WPM',
                  style: Theme.of(context).textTheme.bodySmall,
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
          ],
        ),
      ),
    );
  }
}
 
// Suono del tic: WAV mono 48 kHz, 14 ms, ricavato dal file audio dell'utente.
const String _tickWavBase64 = 'UklGRmQFAABXQVZFZm10IBAAAAABAAEAgLsAAAB3AQACABAAZGF0YUAFAAAAAFj/0/6I/hT+Pf2G/Kr8Sf3a/OL6nfl3+5P+9/1a+TX2iPZn9UHyi/lqF7VDu2brcRhpalQqNzUXBwAA95X0Qe6S4XTSiMTmuR+04LLqs6S2br0VysTae+z4/r8TJCo1PvxKnkxnQrswLB8bEokHWPyd8gTvyPC88PzpD+AX2u7a7+De6pP4aAcFEt0UiBBkB+/73fIN89H/dBQbKAI1ITrENxUu/B6RDnoA3PXb7Yrms90e047KO8k80FPb7eVB70T4rf+8Aq4B6wDIBGQNbRe3H+IkUyZ+I6kcdRP5CbkBtvub+P737/dB9lHyQe3h6M7m+OcJ7FPxQfYc+34BbAkTEKsS8hELEUoR7BBCDkwKNwd6BboD6QBl/SH6s/dP9sn1nPWV9U72PPiD+tf7Zfyn/SYAkwKdA6kDUQSTBqYJdQuKCqIHjwSSAUb9dfdU8hPwn/CI8s70Evcb+RH7Yv0GAGoCNgSUBZUGCQcGBwUHMgdWB6QHkAiECdUIAwbrAlYBTwCW/Uz5RPY89q/3cfjt+Bz7Fv+zAoIESwVABh4H9wbBBTsE2gKaAY0Az/88/77+mf7S/qL+af3M+/36/Pqy+uX52vl3+8D9Bf8P/xT/2P/iAJwBSwJ0A9UEkQUvBfwDhwIsARIASP+3/jv+0/2w/e/9cf75/mH/nv+m/3P/HP/U/sf+Bf+b/4gAnAF6Au4CKQN8A9ADrwPSAoABNQAo/z/+cP3Z/JH8jfyr/Mv85Pwb/bb90f4aACIB0wFoAuIC8QJ+AvsB1AHTAXcBuwATALz/d/8P/7r+xv4r/5H/tv+v/7z/6//+/8L/XP85/5z/VQDiAOwAogB4AJcArQB8AEEAYwDLAN4ARgBp//H+9/7//q/+O/7//f79Af4J/mj+Q/9GAPgAOgFIAV4BgAGcAagBqQGmAZ8BhAFDAegAlQBWAAUAiP8L/9j+9P4c/yr/SP+d//f/AQDA/5n/0v9FAJUAnwCCAFsAJADb/6T/o//T/woAGQDy/6L/T/8i/yz/VP9w/3D/Zv9y/5f/v//Y//H/HwBXAG0ASwARAPH//v8eADQAQABIAEIAFwDN/5P/jv+p/7D/m/+b/8//EgA0ADwAWgCTALoAuQC2ANsAFAEjAfsAzAC4AKgAdwAvAPn/6f/s/+3/6v/m/9v/xf+y/7f/0//s//L/7f/y//v/+f/n/9L/x//B/7f/pf+K/2j/Rv8w/zH/TP93/53/tP+8/8D/xf/J/9D/4v/5/wQA+//u/+z/7//r/+r//f8jAEUATAA3AB0ADgAQAB8ANgBKAE0ARABCAFAAWwBSAEEAQwBYAGEAUAA4ADIAOAA2AC8AOABRAF0ASQAvADIATgBcAEcAKAAgACYAFwDp/8T/yf/i/+H/xP+v/7j/x//C/7v/z//1/wUA9//p/+v/7P/U/7P/qf+3/8H/t/+j/5n/m/+e/5//qf++/9D/1f/W/+H/8v///wYADwAbACUAKgAtAC8ALQAoACcAKwAtACsAJwAmACYAJQAlACcAKQAsAC0AKwAoACUAIgAdABUAEAARABMADgAEAP7//P/4/+//5//q//D/8f/v//L/+f/8//j/8//0//j/+P/2//f/+f/4//T/8P/x//P/9f/1//b/+P/7//3//f/8//3//v8AAAAA//8AAAEAAgACAAIAAwAEAAQAAwADAAQABAADAAIAAgACAAIAAQAAAAAAAQAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=';
 
