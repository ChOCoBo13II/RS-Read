import 'package:shared_preferences/shared_preferences.dart';

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