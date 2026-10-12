# Checking, installing and upgrading the tools from the manifest on macOS.
# Methods: brew (formula), brew-cask (app or prebuilt binary), vendor (the
# maker's own installer command).

BREW_PREFIX=/opt/homebrew
[ "$(uname -m)" = "x86_64" ] && BREW_PREFIX=/usr/local

# Makes brew and the tools it and the vendor installers put in place findable,
# also in a shell that started before they were installed.
env_init() {
  if [ -x "$BREW_PREFIX/bin/brew" ]; then eval "$("$BREW_PREFIX/bin/brew" shellenv)"; fi
  case ":$PATH:" in *":$HOME/.local/bin:"*) ;; *) PATH="$HOME/.local/bin:$PATH" ;; esac
  export PATH
}

has_brew() { command -v brew >/dev/null 2>&1; }

run_check() { [ -n "$1" ] && bash -c "$1" >/dev/null 2>&1; }

# tool_present <id>: installed by any route?
tool_present() {
  local method pkg app check
  method=$(tool "$1" mac.method); pkg=$(tool "$1" mac.package)
  app=$(tool "$1" mac.app); check=$(tool "$1" mac.check)
  case $method in
    brew)      { has_brew && brew list --formula "$pkg" >/dev/null 2>&1; } || run_check "$check" ;;
    brew-cask) { has_brew && brew list --cask "$pkg" >/dev/null 2>&1; } ||
               { [ -n "$app" ] && [ -d "/Applications/$app" ]; } ||
               run_check "$check" ;;
    vendor)    run_check "$check" ;;
    *)         return 1 ;;
  esac
}

# tool_managed_by_brew <id>: installed through Homebrew (so `update` may upgrade it)?
tool_managed_by_brew() {
  local method pkg
  method=$(tool "$1" mac.method); pkg=$(tool "$1" mac.package)
  has_brew || return 1
  case $method in
    brew)      brew list --formula "$pkg" >/dev/null 2>&1 ;;
    brew-cask) brew list --cask "$pkg" >/dev/null 2>&1 ;;
    *)         return 1 ;;
  esac
}

# tool_version <id>: best-effort version string for display
tool_version() {
  local method pkg app check v=""
  method=$(tool "$1" mac.method); pkg=$(tool "$1" mac.package)
  app=$(tool "$1" mac.app); check=$(tool "$1" mac.check)
  if [ -n "$check" ] && [ "$method" = "vendor" ]; then
    v=$(bash -c "$check" 2>/dev/null | head -n 1)
  elif [ "$method" = "brew" ]; then
    has_brew && v=$(brew list --formula --versions "$pkg" 2>/dev/null | awk '{print $2}')
    if [ -z "$v" ] && [ -n "$check" ]; then v=$(bash -c "$check" 2>/dev/null | head -n 1); fi
  elif [ "$method" = "brew-cask" ]; then
    has_brew && v=$(brew list --cask --versions "$pkg" 2>/dev/null | awk '{print $2}')
    if [ -z "$v" ] && [ -n "$app" ] && [ -d "/Applications/$app" ]; then
      v=$(plutil -extract CFBundleShortVersionString raw -o - "/Applications/$app/Contents/Info.plist" 2>/dev/null)
    fi
    if [ -z "$v" ] && [ -n "$check" ]; then v=$(bash -c "$check" 2>/dev/null | head -n 1); fi
  fi
  # Keep only the version number ("git version 2.54.0 (Apple Git-157)" -> 2.54.0).
  printf '%s' "$v" | grep -oE '[0-9]+(\.[0-9]+)+' | head -n 1
}

# tool_route <id>: how it gets installed, for the plan
tool_route() {
  case $(tool "$1" mac.method) in
    brew|brew-cask) printf 'Homebrew' ;;
    vendor)         printf 'official installer' ;;
  esac
}

tool_install() {
  local method pkg cmd
  method=$(tool "$1" mac.method); pkg=$(tool "$1" mac.package); cmd=$(tool "$1" mac.install)
  case $method in
    brew)      brew install "$pkg" ;;
    brew-cask) brew install --cask "$pkg" ;;
    vendor)    bash -c "$cmd" ;;
    *)         return 1 ;;
  esac
}

# tool_upgrade <id>: prints what happened; only for tools that do not update themselves
tool_upgrade() {
  local method pkg cmd
  method=$(tool "$1" mac.method); pkg=$(tool "$1" mac.package); cmd=$(tool "$1" mac.upgrade)
  case $method in
    brew)
      tool_managed_by_brew "$1" || return 3
      if brew outdated --formula --quiet "$pkg" 2>/dev/null | grep -qx "$pkg"; then brew upgrade "$pkg"; else return 2; fi ;;
    brew-cask)
      tool_managed_by_brew "$1" || return 3
      if brew outdated --cask --quiet "$pkg" 2>/dev/null | grep -qx "$pkg"; then brew upgrade --cask "$pkg"; else return 2; fi ;;
    vendor)
      [ -n "$cmd" ] || return 2
      bash -c "$cmd" ;;
  esac
}

install_homebrew() {
  say "Homebrew asks for your Mac password once and may install Apple's Command Line Tools."
  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)" || return 1
  env_init
  # Make brew available in new terminal windows too.
  local line="eval \"\$($BREW_PREFIX/bin/brew shellenv)\""
  if ! grep -qs "brew shellenv" "$HOME/.zprofile"; then
    printf '\n%s\n' "$line" >> "$HOME/.zprofile"
  fi
  has_brew
}
