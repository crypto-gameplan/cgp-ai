# What the person chose, saved between runs in ~/.cgp-ai/selection:
#   profile=builder
#   tool=git
#   plugin=cgp-essentials

SELECTION_FILE="$CGP_HOME/selection"
SEL_PROFILE=""; SEL_TOOLS=""; SEL_PLUGINS=""

in_list() { printf '%s\n' "$2" | grep -qx "$1"; }
add_line() { if [ -z "$1" ]; then printf '%s' "$2"; else printf '%s\n%s' "$1" "$2"; fi; }

sel_exists() { [ -f "$SELECTION_FILE" ]; }

sel_load() {
  SEL_PROFILE=$(sed -n 's/^profile=//p' "$SELECTION_FILE")
  SEL_TOOLS=$(sed -n 's/^tool=//p' "$SELECTION_FILE")
  SEL_PLUGINS=$(sed -n 's/^plugin=//p' "$SELECTION_FILE")
}

sel_save() {
  mkdir -p "$CGP_HOME"
  {
    printf 'profile=%s\n' "$SEL_PROFILE"
    [ -n "$SEL_TOOLS" ] && printf '%s\n' "$SEL_TOOLS" | sed 's/^/tool=/'
    [ -n "$SEL_PLUGINS" ] && printf '%s\n' "$SEL_PLUGINS" | sed 's/^/plugin=/'
  } > "$SELECTION_FILE"
}

sel_from_profile() {
  profile "$1" id >/dev/null || die "Unknown profile '$1'. Choose one of: $(profile_ids | tr '\n' ' ')custom"
  SEL_PROFILE=$1
  SEL_TOOLS=$(profile_tools "$1")
  SEL_PLUGINS=$(profile_plugins "$1")
}

# Asks for every tool and plugin, pre-selecting what the starter profile has.
sel_custom() {
  local id defaults_t defaults_p d
  defaults_t=$(profile_tools starter); defaults_p=$(profile_plugins starter)
  SEL_PROFILE=custom; SEL_TOOLS=""; SEL_PLUGINS=""
  heading "Choose what to install"
  for id in $(tool_ids); do
    d=n; in_list "$id" "$defaults_t" && d=y
    ask_yn "  $(tool "$id" name): $(tool "$id" description)?" "$d" && SEL_TOOLS=$(add_line "$SEL_TOOLS" "$id")
  done
  for id in $(plugin_ids); do
    d=n; in_list "$id" "$defaults_p" && d=y
    ask_yn "  Plugin $(plugin "$id" name): $(plugin "$id" description)?" "$d" && SEL_PLUGINS=$(add_line "$SEL_PLUGINS" "$id")
  done
}

sel_interactive() {
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
  tool "$1" id >/dev/null || die "manifest: unknown tool '$1'"
  for r in $(tool_requires "$1"); do _resolve_add "$r"; done
  RESOLVED_TOOLS=$(add_line "$RESOLVED_TOOLS" "$1")
}
sel_resolve() {
  local id
  RESOLVED_TOOLS=""
  if [ -n "$SEL_PLUGINS" ]; then for id in $(plugin_requires); do _resolve_add "$id"; done; fi
  for id in $SEL_TOOLS; do _resolve_add "$id"; done
}
