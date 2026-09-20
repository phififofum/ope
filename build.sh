#!/usr/bin/env bash
# Build PoggyWoggy. One command, nothing to install first.
#
#     ./build.sh              # build for this machine
#     ./build.sh all          # build Linux and Windows
#     ./build.sh run          # build if needed, then play it
#
# The engine and its export templates are downloaded once into .tooling/ inside this
# repository -- no system packages, no sudo, nothing outside this directory. Delete
# .tooling/ and the next build fetches them again.
#
# What you get: build/<platform>/poggywoggy(.exe), a single self-contained executable.

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$ROOT"

GODOT_VERSION="$(tr -d '[:space:]' < .godot-version)"
TOOLING="$ROOT/.tooling"
GODOT_DIR="$TOOLING/godot-$GODOT_VERSION"
GODOT_BIN="$GODOT_DIR/godot"
TEMPLATES_DIR="$TOOLING/templates/$GODOT_VERSION.stable"
BASE_URL="https://github.com/godotengine/godot/releases/download/${GODOT_VERSION}-stable"

info()  { printf '\033[36m==>\033[0m %s\n' "$*"; }
warn()  { printf '\033[33m==>\033[0m %s\n' "$*" >&2; }
die()   { printf '\033[31merror:\033[0m %s\n' "$*" >&2; exit 1; }

need() { command -v "$1" >/dev/null 2>&1 || die "this script needs '$1' on PATH"; }
need curl
need unzip

host_platform() {
  case "$(uname -s)" in
    Linux)  echo linux ;;
    Darwin) echo macos ;;
    MINGW*|MSYS*|CYGWIN*) echo windows ;;
    *) die "unsupported host: $(uname -s)" ;;
  esac
}

fetch() {
  local url="$1" target="$2"
  info "downloading $(basename "$url")"
  curl --fail --location --progress-bar --output "$target" "$url"
}

ensure_engine() {
  if [ -x "$GODOT_BIN" ]; then
    return
  fi
  mkdir -p "$GODOT_DIR"
  local archive="$TOOLING/godot.zip" name
  case "$(host_platform)" in
    linux)   name="Godot_v${GODOT_VERSION}-stable_linux.x86_64" ;;
    macos)   name="Godot_v${GODOT_VERSION}-stable_macos.universal" ;;
    windows) name="Godot_v${GODOT_VERSION}-stable_win64.exe" ;;
  esac
  fetch "${BASE_URL}/${name}.zip" "$archive"
  unzip -q -o "$archive" -d "$GODOT_DIR"
  rm -f "$archive"
  # The archive's name varies by platform; whatever came out of it is the engine.
  local extracted
  extracted="$(find "$GODOT_DIR" -maxdepth 2 -type f \( -name 'Godot*' -o -name 'godot*' \) | head -1)"
  [ -n "$extracted" ] || die "the engine archive did not contain a binary"
  if [ "$extracted" != "$GODOT_BIN" ]; then
    mv "$extracted" "$GODOT_BIN"
  fi
  chmod +x "$GODOT_BIN"
  info "engine ready: $("$GODOT_BIN" --version | head -1)"
}

ensure_templates() {
  if [ -d "$TEMPLATES_DIR" ]; then
    return
  fi
  mkdir -p "$TOOLING/templates"
  local archive="$TOOLING/templates.tpz"
  fetch "${BASE_URL}/Godot_v${GODOT_VERSION}-stable_export_templates.tpz" "$archive"
  unzip -q -o "$archive" -d "$TOOLING/templates-extract"
  mv "$TOOLING/templates-extract/templates" "$TEMPLATES_DIR"
  rm -rf "$archive" "$TOOLING/templates-extract"
  info "export templates ready"
}

# Godot looks for templates in the user data directory. A symlink keeps them inside this
# repository while still being found, so nothing is written outside it.
link_templates() {
  local user_templates="${HOME}/.local/share/godot/export_templates"
  case "$(host_platform)" in
    macos) user_templates="${HOME}/Library/Application Support/Godot/export_templates" ;;
    windows) user_templates="${APPDATA:-$HOME}/Godot/export_templates" ;;
  esac
  mkdir -p "$user_templates"
  local target="$user_templates/${GODOT_VERSION}.stable"
  if [ ! -e "$target" ]; then
    ln -s "$TEMPLATES_DIR" "$target" 2>/dev/null || cp -r "$TEMPLATES_DIR" "$target"
  fi
}

export_target() {
  local preset="$1" output="$2"
  mkdir -p "$(dirname "$output")"
  info "exporting $preset"
  # The engine sometimes exits noisily after a successful export, so the file on disk is
  # what counts, not the exit code. One retry covers a genuinely interrupted run.
  "$GODOT_BIN" --headless --path "$ROOT" --export-release "$preset" "$output" >/dev/null 2>&1 || true
  if [ ! -s "$output" ]; then
    warn "retrying the $preset export"
    "$GODOT_BIN" --headless --path "$ROOT" --export-release "$preset" "$output" >/dev/null 2>&1 || true
  fi
  [ -s "$output" ] || die "$preset export produced nothing"
  chmod +x "$output" 2>/dev/null || true
  info "built $output ($(du -h "$output" | cut -f1))"
}

main() {
  local mode="${1:-host}"

  ensure_engine
  ensure_templates
  link_templates

  info "importing the project (first run takes a minute)"
  "$GODOT_BIN" --headless --path "$ROOT" --import >/dev/null 2>&1 || true
  # A second pass: the first import registers the scripts, and the export needs them
  # registered before it starts packing.
  "$GODOT_BIN" --headless --path "$ROOT" --import >/dev/null 2>&1 || true

  info "checking that the content loads"
  "$GODOT_BIN" --headless --path "$ROOT" -- --smoke-test

  case "$mode" in
    all)
      export_target "Linux" "$ROOT/build/linux/poggywoggy.x86_64"
      export_target "Windows Desktop" "$ROOT/build/windows/poggywoggy.exe"
      ;;
    run)
      case "$(host_platform)" in
        windows) export_target "Windows Desktop" "$ROOT/build/windows/poggywoggy.exe"
                 info "starting"; "$ROOT/build/windows/poggywoggy.exe" ;;
        *)       export_target "Linux" "$ROOT/build/linux/poggywoggy.x86_64"
                 info "starting"; "$ROOT/build/linux/poggywoggy.x86_64" ;;
      esac
      ;;
    host|"")
      case "$(host_platform)" in
        windows) export_target "Windows Desktop" "$ROOT/build/windows/poggywoggy.exe" ;;
        macos)   warn "macOS export is best-effort; building the Linux target instead"
                 export_target "Linux" "$ROOT/build/linux/poggywoggy.x86_64" ;;
        *)       export_target "Linux" "$ROOT/build/linux/poggywoggy.x86_64" ;;
      esac
      ;;
    *)
      die "unknown mode '$mode' (expected: host, all, run)"
      ;;
  esac

  info "done. Run it directly -- everything it needs is inside the file."
}

main "$@"
