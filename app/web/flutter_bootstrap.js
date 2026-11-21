{{flutter_js}}
{{flutter_build_config}}

// Everything is served by Netmap itself: the ZeroTier network is private and
// the page must not reach the internet. The engine files are bundled by
// `flutter build web --no-web-resources-cdn`; fonts are bundled as assets, and
// the fallback-font folder is local (it is empty on purpose: all text uses the
// bundled Roboto Flex, so nothing ever needs a fallback download).
_flutter.loader.load({
  config: {
    canvasKitBaseUrl: "canvaskit/",
    fontFallbackBaseUrl: "assets/fallback-fonts/",
  },
  onEntrypointLoaded: async (engineInitializer) => {
    const appRunner = await engineInitializer.initializeEngine();
    await appRunner.runApp();
    document.getElementById("splash")?.remove();
  },
});
