// Netmap's look: Material 3 Expressive, "Laguna" seed, fidelity scheme.
//
// Everything visual is derived here from one seed colour, so the light and
// dark themes stay consistent. Link-state colours (direct, relay, one-way) are
// Material "custom colours": a fixed hue harmonised towards the seed, with the
// usual colour / on-colour / container / on-container roles in both themes.
import 'dart:math' as math;

import 'package:material_color_utilities/material_color_utilities.dart' as mcu;
import 'package:material_ui/material_ui.dart';

/// Laguna: the Netmap seed colour.
const Color netmapSeed = Color(0xFF00687A);

const String fontText = 'RobotoFlex';
const String fontMono = 'RobotoMono';

/// The four roles of one link state, in the current theme.
@immutable
class ToneSet {
  const ToneSet(this.color, this.onColor, this.container, this.onContainer);
  final Color color;
  final Color onColor;
  final Color container;
  final Color onContainer;

  static ToneSet lerp(ToneSet a, ToneSet b, double t) => ToneSet(
    Color.lerp(a.color, b.color, t)!,
    Color.lerp(a.onColor, b.onColor, t)!,
    Color.lerp(a.container, b.container, t)!,
    Color.lerp(a.onContainer, b.onContainer, t)!,
  );
}

/// Colours of the link states. "Offline" and "you" come from the scheme
/// itself (outline and primary), so they are not here.
@immutable
class LinkColors extends ThemeExtension<LinkColors> {
  const LinkColors({required this.direct, required this.relay, required this.oneWay});

  final ToneSet direct;
  final ToneSet relay;
  final ToneSet oneWay;

  // design colours before harmonisation: green, amber, red
  static const _direct = 0xFF2E8540;
  static const _relay = 0xFFC77700;
  static const _oneWay = 0xFFC8442A;

  factory LinkColors.of(Brightness b, {Color seed = netmapSeed}) {
    ToneSet tones(int argb) {
      final harmonised = mcu.Blend.harmonize(argb, seed.toARGB32());
      final p = mcu.TonalPalette.of(mcu.Hct.fromInt(harmonised).hue, mcu.Hct.fromInt(harmonised).chroma);
      Color t(int tone) => Color(p.get(tone));
      return b == Brightness.light ? ToneSet(t(40), t(100), t(90), t(10)) : ToneSet(t(80), t(20), t(30), t(90));
    }

    return LinkColors(direct: tones(_direct), relay: tones(_relay), oneWay: tones(_oneWay));
  }

  @override
  LinkColors copyWith({ToneSet? direct, ToneSet? relay, ToneSet? oneWay}) =>
      LinkColors(direct: direct ?? this.direct, relay: relay ?? this.relay, oneWay: oneWay ?? this.oneWay);

  @override
  LinkColors lerp(LinkColors? other, double t) {
    if (other == null) return this;
    return LinkColors(
      direct: ToneSet.lerp(direct, other.direct, t),
      relay: ToneSet.lerp(relay, other.relay, t),
      oneWay: ToneSet.lerp(oneWay, other.oneWay, t),
    );
  }
}

/// Emphasized type: the heavier, wider cut of the scale that M3 Expressive
/// uses for the one thing that matters on a screen ("You're connected").
@immutable
class EmphasizedText extends ThemeExtension<EmphasizedText> {
  const EmphasizedText({
    required this.displayLarge,
    required this.displayMedium,
    required this.displaySmall,
    required this.headlineLarge,
    required this.headlineMedium,
    required this.headlineSmall,
    required this.titleLarge,
    required this.titleMedium,
    required this.labelLarge,
  });

  final TextStyle displayLarge;
  final TextStyle displayMedium;
  final TextStyle displaySmall;
  final TextStyle headlineLarge;
  final TextStyle headlineMedium;
  final TextStyle headlineSmall;
  final TextStyle titleLarge;
  final TextStyle titleMedium;
  final TextStyle labelLarge;

  @override
  EmphasizedText copyWith() => this;

  @override
  EmphasizedText lerp(EmphasizedText? other, double t) => t < .5 ? this : (other ?? this);
}

/// One step of the type scale. Variable font: weight and width are axes, so
/// they are set as font variations as well as [FontWeight].
TextStyle _type(double size, double height, double weight, {double width = 100, double tracking = 0}) => TextStyle(
  fontFamily: fontText,
  fontSize: size,
  height: height / size,
  letterSpacing: tracking,
  fontWeight: FontWeight.values[((weight / 100).round() - 1).clamp(0, 8)],
  fontVariations: [FontVariation.weight(weight), FontVariation.width(width), FontVariation.opticalSize(size)],
);

TextTheme _textTheme() => TextTheme(
  displayLarge: _type(57, 64, 450, tracking: -.25),
  displayMedium: _type(45, 52, 450),
  displaySmall: _type(36, 44, 450),
  headlineLarge: _type(32, 40, 450),
  headlineMedium: _type(28, 36, 450),
  headlineSmall: _type(24, 32, 450),
  titleLarge: _type(22, 28, 500),
  titleMedium: _type(16, 24, 560, tracking: .15),
  titleSmall: _type(14, 20, 560, tracking: .1),
  bodyLarge: _type(16, 24, 400, tracking: .5),
  bodyMedium: _type(14, 20, 400, tracking: .25),
  bodySmall: _type(12, 16, 400, tracking: .4),
  labelLarge: _type(14, 20, 560, tracking: .1),
  labelMedium: _type(12, 16, 560, tracking: .5),
  labelSmall: _type(11, 16, 560, tracking: .5),
);

const EmphasizedText _emphasized = EmphasizedText(
  displayLarge: TextStyle(
    fontFamily: fontText,
    fontSize: 57,
    height: 64 / 57,
    letterSpacing: -.5,
    fontWeight: FontWeight.w800,
    fontVariations: [FontVariation('wght', 800), FontVariation('wdth', 118), FontVariation('opsz', 57)],
  ),
  displayMedium: TextStyle(
    fontFamily: fontText,
    fontSize: 45,
    height: 52 / 45,
    letterSpacing: -.3,
    fontWeight: FontWeight.w800,
    fontVariations: [FontVariation('wght', 780), FontVariation('wdth', 116), FontVariation('opsz', 45)],
  ),
  displaySmall: TextStyle(
    fontFamily: fontText,
    fontSize: 36,
    height: 44 / 36,
    letterSpacing: -.2,
    fontWeight: FontWeight.w700,
    fontVariations: [FontVariation('wght', 760), FontVariation('wdth', 114), FontVariation('opsz', 36)],
  ),
  headlineLarge: TextStyle(
    fontFamily: fontText,
    fontSize: 32,
    height: 40 / 32,
    fontWeight: FontWeight.w700,
    fontVariations: [FontVariation('wght', 740), FontVariation('wdth', 112), FontVariation('opsz', 32)],
  ),
  headlineMedium: TextStyle(
    fontFamily: fontText,
    fontSize: 28,
    height: 36 / 28,
    fontWeight: FontWeight.w700,
    fontVariations: [FontVariation('wght', 720), FontVariation('wdth', 110), FontVariation('opsz', 28)],
  ),
  headlineSmall: TextStyle(
    fontFamily: fontText,
    fontSize: 24,
    height: 32 / 24,
    fontWeight: FontWeight.w700,
    fontVariations: [FontVariation('wght', 700), FontVariation('wdth', 108), FontVariation('opsz', 24)],
  ),
  titleLarge: TextStyle(
    fontFamily: fontText,
    fontSize: 22,
    height: 28 / 22,
    fontWeight: FontWeight.w600,
    fontVariations: [FontVariation('wght', 650), FontVariation('wdth', 104), FontVariation('opsz', 22)],
  ),
  titleMedium: TextStyle(
    fontFamily: fontText,
    fontSize: 16,
    height: 24 / 16,
    letterSpacing: .15,
    fontWeight: FontWeight.w700,
    fontVariations: [FontVariation('wght', 680), FontVariation('wdth', 102), FontVariation('opsz', 16)],
  ),
  labelLarge: TextStyle(
    fontFamily: fontText,
    fontSize: 14,
    height: 20 / 14,
    letterSpacing: .1,
    fontWeight: FontWeight.w700,
    fontVariations: [FontVariation('wght', 680), FontVariation('opsz', 14)],
  ),
);

/// WCAG 2 contrast ratio between two opaque colours (1 … 21).
double contrastRatio(Color a, Color b) {
  final la = a.computeLuminance(), lb = b.computeLuminance();
  return (math.max(la, lb) + .05) / (math.min(la, lb) + .05);
}

/// The Laguna scheme. The fidelity variant keeps the seed's strong colour in
/// its containers, and on some of them Material's "on" colour stays below
/// WCAG AA for small text: those on-colours are pushed along their own tonal
/// palette (same hue, lighter or darker) until they reach 4.5:1.
ColorScheme netmapScheme(Brightness brightness) {
  final s = ColorScheme.fromSeed(seedColor: netmapSeed, brightness: brightness, dynamicSchemeVariant: DynamicSchemeVariant.fidelity);
  Color fix(Color on, Color bg) {
    if (contrastRatio(on, bg) >= 4.5) return on;
    final hct = mcu.Hct.fromInt(on.toARGB32());
    final lighter = mcu.Hct.fromInt(bg.toARGB32()).tone < 50;
    for (var tone = hct.tone; tone >= 0 && tone <= 100; tone += lighter ? 1 : -1) {
      final c = Color(mcu.Hct.from(hct.hue, hct.chroma, tone).toInt());
      if (contrastRatio(c, bg) >= 4.5) return c;
    }
    return lighter ? Colors.white : Colors.black;
  }

  return s.copyWith(
    onPrimary: fix(s.onPrimary, s.primary),
    onPrimaryContainer: fix(s.onPrimaryContainer, s.primaryContainer),
    onSecondary: fix(s.onSecondary, s.secondary),
    onSecondaryContainer: fix(s.onSecondaryContainer, s.secondaryContainer),
    onTertiary: fix(s.onTertiary, s.tertiary),
    onTertiaryContainer: fix(s.onTertiaryContainer, s.tertiaryContainer),
    onErrorContainer: fix(s.onErrorContainer, s.errorContainer),
    onSurfaceVariant: fix(s.onSurfaceVariant, s.surfaceContainerHighest),
  );
}

ThemeData netmapTheme(Brightness brightness) {
  final scheme = netmapScheme(brightness);
  final text = _textTheme().apply(bodyColor: scheme.onSurface, displayColor: scheme.onSurface);
  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    brightness: brightness,
    fontFamily: fontText,
    textTheme: text,
    scaffoldBackgroundColor: scheme.surface,
    materialTapTargetSize: MaterialTapTargetSize.padded,
    visualDensity: VisualDensity.standard,
    // no ripples: nothing on screen animates
    splashFactory: NoSplash.splashFactory,
    // a thin, quiet bar at the window's edge, no track
    scrollbarTheme: ScrollbarThemeData(
      thickness: const WidgetStatePropertyAll(6),
      radius: const Radius.circular(3),
      crossAxisMargin: 4,
      mainAxisMargin: 8,
      thumbColor: WidgetStatePropertyAll(scheme.onSurface.withValues(alpha: .25)),
      trackVisibility: const WidgetStatePropertyAll(false),
    ),
    iconButtonTheme: const IconButtonThemeData(variant: StyleVariant.material3Expressive),
    elevatedButtonTheme: const ElevatedButtonThemeData(variant: StyleVariant.material3Expressive),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size(48, 48),
        shape: const StadiumBorder(),
        padding: const EdgeInsets.symmetric(horizontal: 24),
        textStyle: _emphasized.labelLarge,
      ),
    ),
    // Flat: surfaces are told apart by tone, never by shadows or outlines.
    shadowColor: Colors.transparent,
    chipTheme: ChipThemeData(
      side: BorderSide.none,
      shape: const StadiumBorder(),
      backgroundColor: scheme.surfaceContainerHigh,
      selectedColor: scheme.secondaryContainer,
      checkmarkColor: scheme.onSecondaryContainer,
    ),
    segmentedButtonTheme: SegmentedButtonThemeData(
      style: SegmentedButton.styleFrom(
        side: BorderSide.none,
        backgroundColor: scheme.surfaceContainerHigh,
        selectedBackgroundColor: scheme.secondaryContainer,
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: scheme.surfaceContainerHigh,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
      // the field being typed in still shows it (keyboard users need to see it)
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: scheme.primary, width: 2),
      ),
    ),
    cardTheme: const CardThemeData(elevation: 0),
    menuTheme: MenuThemeData(
      style: MenuStyle(
        elevation: const WidgetStatePropertyAll(0),
        shape: WidgetStatePropertyAll(RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
      ),
    ),
    // above the phone toolbar (its top edge is 96 from the bottom)
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      insetPadding: const EdgeInsets.fromLTRB(16, 0, 16, 104),
    ),
    bottomSheetTheme: BottomSheetThemeData(elevation: 0, modalElevation: 0, backgroundColor: scheme.surfaceContainerLow),
    dialogTheme: const DialogThemeData(elevation: 0),
    tooltipTheme: TooltipThemeData(textStyle: text.bodySmall?.copyWith(color: scheme.onInverseSurface)),
    extensions: [LinkColors.of(brightness), _emphasized.apply(scheme.onSurface)],
  );
}

extension on EmphasizedText {
  EmphasizedText apply(Color c) => EmphasizedText(
    displayLarge: displayLarge.copyWith(color: c),
    displayMedium: displayMedium.copyWith(color: c),
    displaySmall: displaySmall.copyWith(color: c),
    headlineLarge: headlineLarge.copyWith(color: c),
    headlineMedium: headlineMedium.copyWith(color: c),
    headlineSmall: headlineSmall.copyWith(color: c),
    titleLarge: titleLarge.copyWith(color: c),
    titleMedium: titleMedium.copyWith(color: c),
    labelLarge: labelLarge.copyWith(color: c),
  );
}

/// Shortcuts: `context.colors`, `context.links`, `context.type`, `context.em`.
extension ThemeShortcuts on BuildContext {
  ColorScheme get colors => Theme.of(this).colorScheme;
  TextTheme get type => Theme.of(this).textTheme;
  LinkColors get links => Theme.of(this).extension<LinkColors>()!;
  EmphasizedText get em => Theme.of(this).extension<EmphasizedText>()!;
}

// Corner radii: cards (groups), list items, chart marks.
const double rCard = 28;
const double rItem = 16;
const double rMark = 2;
