import 'package:flutter/material.dart';

import 'settings.dart';
import 'tick_player.dart';

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