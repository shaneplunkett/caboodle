{
  lib,
  stdenv,
  bluebubbles,
  fetchzip,
  palette,
}:
let
  colours = palette.hex;
  ffmpeg-kit = fetchzip {
    name = "ffmpeg-kit-linux-x86_64-min-8.1.2";
    url = "https://github.com/sk3llo/ffmpeg_kit_flutter/releases/download/8.1.2-min/ffmpeg-kit-linux-x86_64-min-8.1.2.tar.gz";
    hash = "sha256-O5hDf12HfUzKxemp1IIuWTYd48rdPYEIIbUSP0gVRcU=";
    stripRoot = false;
  };
in

bluebubbles.overrideAttrs (old: {
  env =
    (old.env or { })
    // lib.optionalAttrs stdenv.hostPlatform.isx86_64 {
      FFMPEGKIT_LOCAL_DIR = "${ffmpeg-kit}/ffmpeg-kit";
    };
  postPatch = (old.postPatch or "") + ''
        substituteInPlace lib/services/ui/theme/themes_service.dart \
          --replace-fail '  static List<ThemeStruct> get defaultThemes => [' \
            '  static final shaneDesktopTheme = FlexColorScheme(
      textTheme: Typography.englishLike2021.merge(Typography.whiteMountainView),
      colorScheme: ColorScheme(
        brightness: Brightness.dark,
        primary: HexColor("${colours.mauve}"),
        onPrimary: HexColor("${colours.crust}"),
        primaryContainer: HexColor("${colours.blue}"),
        onPrimaryContainer: HexColor("${colours.crust}"),
        secondary: HexColor("${colours.pink}"),
        onSecondary: HexColor("${colours.crust}"),
        secondaryContainer: HexColor("${colours.surface1}"),
        onSecondaryContainer: HexColor("${colours.text}"),
        tertiary: HexColor("${colours.green}"),
        onTertiary: HexColor("${colours.crust}"),
        tertiaryContainer: HexColor("${colours.surface0}"),
        onTertiaryContainer: HexColor("${colours.green}"),
        error: HexColor("${colours.red}"),
        onError: HexColor("${colours.crust}"),
        errorContainer: HexColor("${colours.maroon}"),
        onErrorContainer: HexColor("${colours.crust}"),
        surface: HexColor("${colours.mantle}"),
        onSurface: HexColor("${colours.text}"),
        surfaceContainerLowest: HexColor("${colours.crust}"),
        surfaceContainerLow: HexColor("${colours.base}"),
        surfaceContainer: HexColor("${colours.surface0}"),
        surfaceContainerHigh: HexColor("${colours.surface1}"),
        surfaceContainerHighest: HexColor("${colours.surface2}"),
        onSurfaceVariant: HexColor("${colours.subtext0}"),
        outline: HexColor("${colours.overlay1}"),
        shadow: HexColor("${colours.crust}"),
        inverseSurface: HexColor("${colours.text}"),
        onInverseSurface: HexColor("${colours.base}"),
        inversePrimary: HexColor("${colours.lavender}"),
      ),
      useMaterial3: true,
    ).toTheme.copyWith(splashFactory: InkSparkle.splashFactory, extensions: [
      BubbleColors(
        iMessageBubbleColor: HexColor("${colours.blue}"),
        oniMessageBubbleColor: HexColor("${colours.crust}"),
        smsBubbleColor: HexColor("${colours.green}"),
        onSmsBubbleColor: HexColor("${colours.crust}"),
        receivedBubbleColor: HexColor("${colours.surface0}"),
        onReceivedBubbleColor: HexColor("${colours.text}"),
      ),
      BubbleText(
        bubbleText: Typography.englishLike2021.bodyMedium!.copyWith(
          fontSize: 15,
          height: Typography.englishLike2021.bodyMedium!.height! * 0.85,
          color: HexColor("${colours.text}"),
        ),
      ),
    ]);

    static List<ThemeStruct> get defaultThemes => ['

        substituteInPlace lib/services/ui/theme/themes_service.dart \
          --replace-fail '    ThemeStruct(name: "OLED Dark", themeData: oledDarkTheme),' \
            '    ThemeStruct(name: "Shane Desktop", themeData: shaneDesktopTheme),
      ThemeStruct(name: "OLED Dark", themeData: oledDarkTheme),'

    substituteInPlace lib/database/io/theme.dart \
      --replace-fail '    final name = PrefsSvc.theme.getSelectedLightTheme();' \
        '    final name = PrefsSvc.theme.getSelectedLightTheme();
    if (name == "Shane Desktop") {
      return ThemeStruct(name: "Shane Desktop", themeData: ThemesService.shaneDesktopTheme);
    }'

    substituteInPlace lib/database/io/theme.dart \
      --replace-fail '    final name = PrefsSvc.theme.getSelectedDarkTheme();' \
        '    final name = PrefsSvc.theme.getSelectedDarkTheme();
    if (name == null || name == "OLED Dark" || name == "Shane Desktop") {
      return ThemeStruct(name: "Shane Desktop", themeData: ThemesService.shaneDesktopTheme);
    }'

  '';
})
