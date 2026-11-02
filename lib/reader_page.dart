import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import 'backdrop.dart';
import 'scrub_bar.dart';
import 'settings.dart';
import 'settings_page.dart';
import 'theme.dart';
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

class _ReaderPageState extends State<ReaderPage>
    with WidgetsBindingObserver, SingleTickerProviderStateMixin {
  static const double _dpPerCm = 63.0;

  int _index = 0;
  double _wpm = 300;
  bool _playing = false;
  bool _fullscreen = false;
  bool _hintVisible = false;
  bool _seekWasPlaying = false;
  int _sinceStart = 0;
  ReadSettings _settings = ReadSettings();
  Timer? _timer;
  Timer? _hintTimer;
  DateTime _due = DateTime.now();

  // Margini dello schermo congelati mentre dura il Focus e le animazioni,
  // così il Player non scatta quando le barre di sistema spariscono.
  EdgeInsets? _padLock;

  // Animazione del Focus: 0 = Player, 1 = Focus. Ingresso 350 ms, uscita 300 ms.
  late final AnimationController _ac = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 350),
    reverseDuration: const Duration(milliseconds: 300),
  );
  late final CurvedAnimation _anim =
      CurvedAnimation(parent: _ac, curve: Curves.easeInOut);

  late final Set<int> _paraEnds =
      widget.starts.where((s) => s > 0).map((s) => s - 1).toSet();

  @override
  void initState() {
    super.initState();
    _index = widget.startIndex.clamp(0, widget.words.length - 1);
    WidgetsBinding.instance.addObserver(this);
    _ac.addStatusListener(_onAnimStatus);
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
    _hintTimer?.cancel();
    _anim.dispose();
    _ac.dispose();
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

  void _onAnimStatus(AnimationStatus status) {
    if (status == AnimationStatus.completed && _fullscreen) {
      _showFullscreenHint();
    } else if (status == AnimationStatus.dismissed && mounted) {
      setState(() => _padLock = null);
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
    final rampWords = _settings.gradualWords;
    final steps = _sinceStart < rampWords ? _sinceStart : rampWords;
    final start = _settings.gradualStart;
    final ramp =
        _settings.gradual ? start + (1 - start) * steps / rampWords : 1.0;
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

  // Un tocco durante l'animazione la inverte da dove si trova.
  void _toggleFullscreen() {
    final enter = !_fullscreen;
    _padLock ??= MediaQuery.of(context).padding;
    setState(() => _fullscreen = enter);
    SystemChrome.setEnabledSystemUIMode(
      enter ? SystemUiMode.immersiveSticky : SystemUiMode.edgeToEdge,
    );
    if (enter) {
      _ac.forward();
    } else {
      _hideHint();
      _ac.reverse();
    }
  }

  void _showFullscreenHint() {
    if (!_settings.showFullscreenHint) return;
    _hintTimer?.cancel();
    setState(() => _hintVisible = true);
    _hintTimer = Timer(const Duration(seconds: 6), _hideHint);
  }

  void _hideHint() {
    _hintTimer?.cancel();
    if (_hintVisible && mounted) setState(() => _hintVisible = false);
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

  // Velocità da frazione della barra (100–1000 WPM, passi da 10).
  double _wpmFrom(double f) => 100 + (f * 90).round() * 10.0;

  // Parola + zone di pausa + area di tocco della parola. La parola sta
  // sempre al centro dello schermo. fontW è la larghezza di riferimento per
  // la dimensione del carattere (sempre quella della card). t è l'avanzamento
  // dell'animazione (0 = Player, 1 = Focus): sposta gradualmente le zone
  // dal centro alla posizione impostata per il Focus.
  Widget _wordStack(double areaW, double areaH, double fontW, double t) {
    final word = widget.words[_index];
    final p = _pivot(word);
    final side = p > word.length - 1 - p ? p : word.length - 1 - p;
    final half = fontW / 2 - 16;
    final fit = half / ((side + 0.5) * 0.65);
    final style = TextStyle(
      fontSize: fit < 40.0 ? fit : 40.0,
      fontWeight: FontWeight.w500,
      fontFamily: 'monospace',
      color: Colors.white,
    );

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

    final margin = _settings.zoneMargin * _dpPerCm;
    final alpha = (_settings.zoneOpacity * 255).round();
    // Nel Focus vale la posizione impostata; fuori dal Focus le zone stanno
    // sempre al centro della parola.
    final vertical = 0.5 + (_settings.zoneVertical - 0.5) * t;

    Widget zone({
      required bool left,
      required double wCm,
      required double hCm,
    }) {
      final zw = math.max(0.0, math.min(wCm * _dpPerCm, areaW - margin));
      final zh = math.min(hCm * _dpPerCm, areaH);
      var top = vertical * areaH - zh / 2;
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
          child: ColoredBox(color: Colors.white.withAlpha(alpha)),
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
            Text(word[p], style: style.copyWith(color: Ui.red)),
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
        if (!leftAbove) zone(left: true, wCm: leftW, hCm: leftH),
        if (!rightAbove) zone(left: false, wCm: rightW, hCm: rightH),
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
        if (rightAbove) zone(left: false, wCm: rightW, hCm: rightH),
      ],
    );
  }

  Widget _header() {
    return Glass(
      radius: 28,
      child: Row(
        children: [
          IconButton(
            tooltip: 'Indietro',
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(Icons.chevron_left, size: 30, color: Ui.ink),
          ),
          const Expanded(
            child: Text(
              'Lettura',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: Ui.ink,
              ),
            ),
          ),
          IconButton(
            tooltip: 'Dall’inizio',
            onPressed: _restart,
            icon: const Icon(Icons.replay, color: Ui.ink),
          ),
          IconButton(
            tooltip: 'Modalità Focus',
            onPressed: _toggleFullscreen,
            icon: const Icon(Icons.fullscreen, color: Ui.ink),
          ),
          IconButton(
            tooltip: 'Impostazioni',
            onPressed: _openSettings,
            icon: const Icon(Icons.tune, color: Ui.ink),
          ),
        ],
      ),
    );
  }

  Widget _capsule() {
    Widget btn(String tip, IconData icon, VoidCallback onTap) {
      return IconButton(
        tooltip: tip,
        onPressed: onTap,
        padding: EdgeInsets.zero,
        constraints: const BoxConstraints.tightFor(width: 38, height: 48),
        icon: Icon(icon, size: 26, color: Ui.yellow),
      );
    }

    const gap = SizedBox(width: 8);
    return Container(
      height: 76,
      decoration: const BoxDecoration(
        color: Ui.ink,
        borderRadius: BorderRadius.all(Radius.circular(38)),
      ),
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              btn('Paragrafo indietro', Icons.skip_previous, _paragraphBack),
              gap,
              btn(
                'Frase indietro',
                Icons.keyboard_double_arrow_left,
                _sentenceBack,
              ),
              gap,
              btn('Parola indietro', Icons.chevron_left, () => _goTo(_index - 1)),
              gap,
              SizedBox(
                width: 54,
                height: 54,
                child: IconButton(
                  tooltip: _playing ? 'Pausa' : 'Riproduci',
                  onPressed: _toggle,
                  style: IconButton.styleFrom(
                    backgroundColor: Ui.yellow,
                    foregroundColor: Ui.ink,
                    shape: const CircleBorder(),
                    padding: EdgeInsets.zero,
                  ),
                  icon: Icon(
                    _playing ? Icons.pause : Icons.play_arrow,
                    size: 30,
                  ),
                ),
              ),
              gap,
              btn('Parola avanti', Icons.chevron_right, () => _goTo(_index + 1)),
              gap,
              btn(
                'Frase avanti',
                Icons.keyboard_double_arrow_right,
                _sentenceForward,
              ),
              gap,
              btn('Paragrafo avanti', Icons.skip_next, _paragraphForward),
            ],
          ),
        ),
      ),
    );
  }

  Widget _controls(int total, int remaining) {
    const mute = TextStyle(
      fontSize: 13,
      fontWeight: FontWeight.w600,
      color: Color(0xB3000000),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Parola ${_index + 1} di $total · restano circa ${_fmt(remaining)}',
          textAlign: TextAlign.center,
          style: mute,
        ),
        const SizedBox(height: 10),
        ScrubBar(
          value: total > 1 ? _index / (total - 1) : 0.0,
          onChangeStart: () {
            _seekWasPlaying = _playing;
            _timer?.cancel();
            setState(() => _playing = false);
          },
          onChanged: (f) {
            setState(() => _index = (f * (total - 1)).round().clamp(0, total - 1));
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
        const SizedBox(height: 10),
        Text('Velocità: ${_wpm.round()} WPM', style: mute),
        const SizedBox(height: 2),
        ScrubBar(
          value: (_wpm - 100) / 900,
          divisions: 90,
          onChanged: (f) => setState(() => _wpm = _wpmFrom(f)),
          onChangeEnd: (f) => SharedPreferences.getInstance()
              .then((prefs) => prefs.setDouble('wpm', _wpmFrom(f))),
        ),
        const Spacer(),
        _capsule(),
      ],
    );
  }

  // Banner di suggerimento della Modalità Focus: giallo, 104 px di altezza,
  // a 44 px dal bordo basso (la posizione è nel build).
  Widget _hintBanner() {
    const base = TextStyle(
      fontSize: 14,
      fontWeight: FontWeight.w700,
      letterSpacing: 0.2,
    );
    return Material(
      color: Ui.yellow,
      shape: Ui.shape,
      child: SizedBox(
        height: 104,
        child: Stack(
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 14, 24, 0),
              child: Text(
                'Modalità Focus: tocca i lati per la pausa, la parola per uscire',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  height: 1.35,
                  color: Ui.ink,
                ),
              ),
            ),
            Positioned(
              right: 16,
              bottom: 12,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () {
                  _settings.showFullscreenHint = false;
                  _settings.save();
                  _hideHint();
                },
                child: Container(
                  height: 30,
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    border: Border.all(color: Ui.ink, width: 2),
                    borderRadius: const BorderRadius.all(Radius.circular(15)),
                  ),
                  child: Stack(
                    children: [
                      Text(
                        'Non mostrare più',
                        style: base.copyWith(
                          foreground: Paint()
                            ..style = PaintingStyle.stroke
                            ..strokeWidth = 1.8
                            ..strokeJoin = StrokeJoin.round
                            ..color = Ui.ink,
                        ),
                      ),
                      Text(
                        'Non mostrare più',
                        style: base.copyWith(color: Ui.red),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Scena: la macchia nera (card che diventa cerchio), la parola ferma al
  // centro, l'intestazione che esce in alto e i comandi che escono in basso.
  // t: 0 = Player, 1 = Focus.
  Widget _stage(
    BuildContext ctx,
    BoxConstraints c,
    double t,
    int total,
    int remaining,
  ) {
    final w = c.maxWidth;
    final h = c.maxHeight;
    final pad = _padLock ?? MediaQuery.of(ctx).padding;

    final cardW = w - 40;
    final cardH = h * 0.35;
    final cardTop = h / 2 - cardH / 2;
    final diameter = math.sqrt(w * w + h * h) + 40;

    // La larghezza cresce prima dell'altezza; gli angoli arrivano alla
    // curvatura piena già al 45% dell'animazione.
    final shapeW = cardW + (diameter - cardW) * math.pow(t, 1.5).toDouble();
    final shapeH = cardH + (diameter - cardH) * math.pow(t, 2.2).toDouble();
    final k = math.min(1.0, t / 0.45);
    final curl = 1 - (1 - k) * (1 - k);
    final radius =
        Ui.radius + (math.min(shapeW, shapeH) / 2 - Ui.radius) * curl;
    final areaW = math.min(shapeW, w);
    final areaH = math.min(shapeH, h);

    final headerDy = -(pad.top + 80) * t;
    final controlsTop = cardTop + cardH + 12;
    final controlsDy = (h - controlsTop + 20) * t;
    final moving = t > 0.01;

    return Stack(
      children: [
        Positioned(
          left: (w - shapeW) / 2,
          top: (h - shapeH) / 2,
          width: shapeW,
          height: shapeH,
          child: Container(
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              color: Ui.ink,
              borderRadius: BorderRadius.circular(radius),
            ),
            child: Center(
              child: SizedBox(
                width: areaW,
                height: areaH,
                child: _wordStack(areaW, areaH, cardW, t),
              ),
            ),
          ),
        ),
        Positioned(
          top: pad.top + 8,
          left: 20,
          right: 20,
          height: 56,
          child: IgnorePointer(
            ignoring: moving,
            child: Transform.translate(
              offset: Offset(0, headerDy),
              child: _header(),
            ),
          ),
        ),
        Positioned(
          top: controlsTop,
          left: 20,
          right: 20,
          bottom: pad.bottom + 16,
          child: IgnorePointer(
            ignoring: moving,
            child: Transform.translate(
              offset: Offset(0, controlsDy),
              child: _controls(total, remaining),
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final total = widget.words.length;
    final remaining = ((total - _index) * 60 / _wpm).round();

    return Theme(
      data: Ui.yellowTheme,
      child: AnimatedBuilder(
        animation: _anim,
        builder: (context, _) {
          final t = _anim.value;
          return AnnotatedRegion<SystemUiOverlayStyle>(
            value: t > 0.5 ? SystemUiOverlayStyle.light : Ui.yellowOverlay,
            child: Stack(
              children: [
                Positioned.fill(
                  child: t >= 1
                      ? const ColoredBox(color: Ui.ink)
                      : const AppBackdrop(),
                ),
                Scaffold(
                  backgroundColor: Colors.transparent,
                  body: LayoutBuilder(
                    builder: (ctx, c) => _stage(ctx, c, t, total, remaining),
                  ),
                ),
                Positioned(
                  left: 20,
                  right: 20,
                  bottom: 44,
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 200),
                    child: _fullscreen && _hintVisible
                        ? _hintBanner()
                        : const SizedBox.shrink(),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}