import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import 'settings.dart';
import 'settings_page.dart';
import 'tick_player.dart';

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