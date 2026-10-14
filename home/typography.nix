# Fonts — the single source of truth, delivered exactly like palette.nix:
# home-manager modules via extraSpecialArgs and system modules via specialArgs
# as `typography`; packages take it as an explicit callPackage argument.
{
  # Interfaces: shells, toolkits, app chrome.
  ui = "RoundHog";
  # Anything that needs a fixed width: terminals, editors, code blocks.
  code = "Mononoki Nerd Font";
  # Strictly single-width glyphs, for apps that measure cells themselves.
  codeMono = "Mononoki Nerd Font Mono";
}
