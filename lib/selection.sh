# What the person chose, saved between runs in ~/.cgp-ai/selection:
#   provider=both            (claude, openai or both)
#   profile=builder
#   tool=git
#   plugin=cgp-essentials
#   confirmed=claude-desktop (a sign-in the person confirmed and cgp-ai cannot check)

SELECTION_FILE="$CGP_HOME/selection"
SEL_PROVIDER=""; SEL_PROFILE=""; SEL_TOOLS=""; SEL_PLUGINS=""; SEL_CONFIRMED=""
SEL_WITH=""   # optional tools asked for with --with, so they are not asked again

in_list() { printf '%s\n' "$2" | grep -qx "$1"; }
add_line() { if [ -z "$1" ]; then printf '%s' "$2"; else printf '%s\n%s' "$1" "$2"; fi; }

sel_exists() { [ -f "$SELECTION_FILE" ]; }

sel_load() {
  SEL_PROVIDER=$(sed -n 's/^provider=//p' "$SELECTION_FILE")
  SEL_PROFILE=$(sed -n 's/^profile=//p' "$SELECTION_FILE")
  SEL_TOOLS=$(sed -n 's/^tool=//p' "$SELECTION_FILE")
  SEL_PLUGINS=$(sed -n 's/^plugin=//p' "$SELECTION_FILE")
  SEL_CONFIRMED=$(sed -n 's/^confirmed=//p' "$SELECTION_FILE")
  [ -n "$SEL_PROVIDER" ] || SEL_PROVIDER=both
}

sel_save() {
  mkdir -p "$CGP_HOME"
  {
    printf 'provider=%s\n' "$SEL_PROVIDER"
    printf 'profile=%s\n' "$SEL_PROFILE"
    [ -n "$SEL_TOOLS" ] && printf '%s\n' "$SEL_TOOLS" | sed 's/^/tool=/'
    [ -n "$SEL_PLUGINS" ] && printf '%s\n' "$SEL_PLUGINS" | sed 's/^/plugin=/'
    [ -n "$SEL_CONFIRMED" ] && printf '%s\n' "$SEL_CONFIRMED" | sed 's/^/confirmed=/'
  } > "$SELECTION_FILE"
}

sel_confirm()      { in_list "$1" "$SEL_CONFIRMED" || SEL_CONFIRMED=$(add_line "$SEL_CONFIRMED" "$1"); }
sel_is_confirmed() { in_list "$1" "$SEL_CONFIRMED"; }

# provider_ok <provider of an item>: does it belong to the AI the person uses?
provider_ok() { [ -z "$1" ] || [ "$SEL_PROVIDER" = "both" ] || [ "$SEL_PROVIDER" = "$1" ]; }
tool_wanted()   { provider_ok "$(tool "$1" provider)"; }
plugin_wanted() { provider_ok "$(plugin "$1" provider)"; }

_only_wanted_tools()   { local id; for id in $1; do tool_wanted "$id" && echo "$id"; done; }
_only_wanted_plugins() { local id; for id in $1; do plugin_wanted "$id" && echo "$id"; done; }

sel_set_provider() {
  case $1 in
    claude|openai|both) SEL_PROVIDER=$1 ;;
    *) die "Unknown provider '$1'. Choose claude, openai or both." ;;
  esac
}

sel_ask_provider() {
  heading "Which AI do you work with?"
  say "  1) $(m_get providers.0.name)"
  say "  2) $(m_get providers.1.name)"
  say "  3) Both"
  case $(ask_choice "AI" 3) in
    1) SEL_PROVIDER=claude ;;
    2) SEL_PROVIDER=openai ;;
    3) SEL_PROVIDER=both ;;
  esac
}

sel_from_profile() {
  profile "$1" id >/dev/null || die "Unknown profile '$1'. Choose one of: $(profile_ids | tr '\n' ' ')custom"
  SEL_PROFILE=$1
  SEL_TOOLS=$(_only_wanted_tools "$(profile_tools "$1")")
  SEL_PLUGINS=$(_only_wanted_plugins "$(profile_plugins "$1")")
  _ask_optional "$1"
}

# Optional tools of a profile: asked one by one, no by default. --yes skips them unless --with names them.
_ask_optional() {
  local id asked=0
  for id in $(profile_optional "$1"); do
    tool_wanted "$id" || continue
    if in_list "$id" "$SEL_WITH"; then
      SEL_TOOLS=$(add_line "$SEL_TOOLS" "$id")
    elif [ "${CGP_ASSUME_YES:-0}" != "1" ]; then
      [ "$asked" = "1" ] || { heading "Optional for $(profile "$1" name)"; asked=1; }
      ask_yn "  $(tool "$id" name): $(tool "$id" description)?" n && SEL_TOOLS=$(add_line "$SEL_TOOLS" "$id")
    fi
  done
}

# Asks for every tool and plugin of the chosen AI, pre-selecting what the starter profile has.
sel_custom() {
  local id defaults_t defaults_p d
  defaults_t=$(profile_tools starter); defaults_p=$(profile_plugins starter)
  SEL_PROFILE=custom; SEL_TOOLS=""; SEL_PLUGINS=""
  heading "Choose what to install"
  for id in $(tool_ids); do
    tool_wanted "$id" || continue
    d=n; in_list "$id" "$defaults_t" && d=y
    ask_yn "  $(tool "$id" name): $(tool "$id" description)?" "$d" && SEL_TOOLS=$(add_line "$SEL_TOOLS" "$id")
  done
  for id in $(plugin_ids); do
    plugin_wanted "$id" || continue
    d=n; in_list "$id" "$defaults_p" && d=y
    ask_yn "  Plugin $(plugin "$id" name): $(plugin "$id" description)?" "$d" && SEL_PLUGINS=$(add_line "$SEL_PLUGINS" "$id")
  done
}

sel_ask_profile() {
  local n i=1 id choice
  n=$(m_count profiles)
  heading "Choose a profile"
  for id in $(profile_ids); do
    say "  $i) $(profile "$id" name): $(profile "$id" description)"
    i=$((i + 1))
  done
  say "  $i) Custom: pick each tool yourself"
  choice=$(ask_choice "Profile" "$i")
  if [ "$choice" -le "$n" ]; then
    sel_from_profile "$(profile_ids | sed -n "${choice}p")"
  else
    sel_custom
  fi
}

# RESOLVED_TOOLS: the chosen tools plus everything they need, dependencies first.
RESOLVED_TOOLS=""
_resolve_add() {
  local r
  in_list "$1" "$RESOLVED_TOOLS" && return
  # A tool removed or renamed in a newer manifest may still be in an old selection.
  tool "$1" id >/dev/null || { warn "'$1' is no longer offered and is skipped"; return; }
  for r in $(tool_requires "$1"); do _resolve_add "$r"; done
  RESOLVED_TOOLS=$(add_line "$RESOLVED_TOOLS" "$1")
}
sel_resolve() {
  local id
  RESOLVED_TOOLS=""
  if [ -n "$SEL_PLUGINS" ]; then for id in $(plugin_requires); do _resolve_add "$id"; done; fi
  for id in $SEL_TOOLS; do _resolve_add "$id"; done
}
