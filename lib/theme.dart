import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Colori e misure comuni del nuovo stile (giallo, nero, rosso della lettera).
class Ui {
  Ui._();

  static const Color yellow = Color(0xFFFFCC00);
  static const Color ink = Color(0xFF000000);

  /// Fondo delle card e dei pulsanti scuri (non è nero puro).
  static const Color card = Color(0xFF010B13);
  static const Color red = Color(0xFFFF5252);
  static const Color muted = Color(0xFF8E8E93);
  static const Color glassTint = Color(0x2BFF5252);
  static const Color glassBorder = Color(0xA5FFFFFF);

  static const double radius = 25;
  static const BorderRadius corners = BorderRadius.all(Radius.circular(radius));
  static const RoundedRectangleBorder shape =
      RoundedRectangleBorder(borderRadius: corners);

  /// Barre di stato trasparenti con icone scure (sui fondi gialli).
  static const SystemUiOverlayStyle yellowOverlay = SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.dark,
    statusBarBrightness: Brightness.light,
    systemNavigationBarColor: Colors.transparent,
    systemNavigationBarIconBrightness: Brightness.dark,
    systemNavigationBarContrastEnforced: false,
  );

  static final ThemeData yellowTheme = _buildYellow();
  static final ThemeData blackCardTheme = _onBlack(yellowTheme);

  static ThemeData _buildYellow() {
    const scheme = ColorScheme.light(
      primary: ink,
      onPrimary: yellow,
      secondary: ink,
      onSecondary: yellow,
      surface: yellow,
      onSurface: ink,
      onSurfaceVariant: ink,
      error: red,
    );
    final base = ThemeData(useMaterial3: true, colorScheme: scheme);
    return base.copyWith(
      scaffoldBackgroundColor: Colors.transparent,
      textTheme: base.textTheme.apply(bodyColor: ink, displayColor: ink),
      textSelectionTheme: const TextSelectionThemeData(
        cursorColor: yellow,
        selectionHandleColor: yellow,
        selectionColor: Color(0x66FFCC00),
      ),
      sliderTheme: SliderThemeData(
        trackHeight: 6,
        activeTrackColor: yellow,
        inactiveTrackColor: const Color(0x40FFFFFF),
        thumbColor: Colors.white,
        overlayColor: const Color(0x29FFCC00),
        tickMarkShape: SliderTickMarkShape.noTickMark,
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected) ? ink : muted,
        ),
        trackColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? yellow
              : const Color(0xFF3A3A3C),
        ),
        trackOutlineColor: const WidgetStatePropertyAll(Colors.transparent),
      ),
    );
  }

  /// Variante per il contenuto dentro le card scure (testo bianco).
  static ThemeData _onBlack(ThemeData t) {
    return t.copyWith(
      colorScheme: t.colorScheme.copyWith(
        onSurface: Colors.white,
        onSurfaceVariant: muted,
        surface: card,
      ),
      textTheme: t.textTheme.apply(
        bodyColor: Colors.white,
        displayColor: Colors.white,
      ),
      listTileTheme: const ListTileThemeData(iconColor: Colors.white),
      dividerTheme: const DividerThemeData(color: Color(0x33FFFFFF)),
    );
  }
}