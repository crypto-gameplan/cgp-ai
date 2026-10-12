# setup, update and doctor.

require_macos() {
  [ "$(uname -s)" = "Darwin" ] || die "This version of cgp-ai runs on macOS. Windows follows."
}

_tool_line() { printf '%s' "$(tool "$1" name)"; }

_note_reason() {
  # Why a tool is in the plan although the person did not pick it.
  in_list "$1" "$SEL_TOOLS" && return
  printf ' (needed by your selection)'
}

# ---------------------------------------------------------------- setup

cmd_setup() {
  local dry=0 change=0 want_profile="" id v missing_tools="" missing_plugins="" failed="" need_brew=0 need_market=0
  while [ $# -gt 0 ]; do
    case $1 in
      --dry-run) dry=1 ;;
      --change)  change=1 ;;
      --yes|-y)  export CGP_ASSUME_YES=1 ;;
      --profile) shift; want_profile=${1:-} ;;
      --profile=*) want_profile=${1#--profile=} ;;
      *) die "Unknown option '$1'. See: cgp-ai help" ;;
    esac
    shift
  done

  require_macos
  env_init
  heading "cgp-ai $(cgp_version) on macOS $(sw_vers -productVersion) ($(uname -m))"

  if [ -n "$want_profile" ]; then
    if [ "$want_profile" = "custom" ]; then sel_custom; else sel_from_profile "$want_profile"; fi
  elif sel_exists && [ "$change" = "0" ]; then
    sel_load
    say "Using your saved selection ($SEL_PROFILE). Run 'cgp-ai setup --change' to choose again."
  else
    sel_interactive
  fi
  sel_resolve

  # Plan
  heading "Plan"
  has_brew || { need_brew=1; todo "Homebrew: will be installed (needed for everything else)"; }
  for id in $RESOLVED_TOOLS; do
    if tool_present "$id"; then
      v=$(tool_version "$id"); ok "$(_tool_line "$id")${v:+ $v}"
    else
      todo "$(_tool_line "$id"): will be installed via $(tool_route "$id")$(_note_reason "$id")"
      missing_tools=$(add_line "$missing_tools" "$id")
    fi
  done
  if [ -n "$SEL_PLUGINS" ]; then
    if marketplace_conflict; then
      warn "Another marketplace named '$(marketplace_name)' is set up in Claude Code."
      hint "Remove it first: claude plugin marketplace remove $(marketplace_name)"
    elif marketplace_present; then
      ok "Crypto Gameplan marketplace"
    else
      need_market=1; todo "Crypto Gameplan marketplace: will be added to Claude Code"
    fi
    for id in $SEL_PLUGINS; do
      if plugin_present "$id"; then
        ok "Plugin $(plugin "$id" name) $(plugin_version "$id")"
      else
        todo "Plugin $(plugin "$id" name): will be installed"
        missing_plugins=$(add_line "$missing_plugins" "$id")
      fi
    done
  fi
  for id in $missing_tools; do
    v=$(tool "$id" mac.note); [ -n "$v" ] && hint "$(tool "$id" name): $v"
  done

  if [ "$dry" = "1" ]; then
    say ""; say "Dry run: nothing was changed."; return 0
  fi
  if [ "$need_brew$need_market" = "00" ] && [ -z "$missing_tools$missing_plugins" ]; then
    sel_save; say ""; say "Everything is set up. Run 'cgp-ai update' now and then to stay current."; return 0
  fi
  say ""
  ask_yn "Install the items marked +?" y || { say "Nothing was changed."; return 0; }

  # Install
  if [ "$need_brew" = "1" ]; then
    heading "Installing Homebrew"
    install_homebrew || die "Homebrew could not be installed. Nothing else was changed."
  fi
  for id in $missing_tools; do
    heading "Installing $(tool "$id" name)"
    if tool_install "$id" && { env_init; tool_present "$id"; }; then ok "$(tool "$id" name) installed"
    else fail "$(tool "$id" name) could not be installed"; failed=$(add_line "$failed" "$(tool "$id" name)"); fi
  done
  if [ -n "$SEL_PLUGINS" ]; then
    if ! has_claude; then
      fail "Claude Code CLI is missing, so the plugins could not be installed"
      failed=$(add_line "$failed" "Plugins")
    else
      if [ "$need_market" = "1" ]; then
        heading "Adding the Crypto Gameplan marketplace"
        marketplace_add || failed=$(add_line "$failed" "Marketplace")
      fi
      for id in $missing_plugins; do
        heading "Installing plugin $(plugin "$id" name)"
        plugin_install "$id" || failed=$(add_line "$failed" "Plugin $(plugin "$id" name)")
      done
    fi
  fi
  sel_save

  # Summary
  heading "Done"
  if [ -n "$failed" ]; then
    printf '%s\n' "$failed" | while IFS= read -r v; do fail "$v"; done
    hint "Run 'cgp-ai doctor' for details, or post its output in the CGP AI Lab."
  else
    ok "Everything on your list is installed."
  fi
  say ""
  say "Next steps:"
  say "  - Open a new terminal window so the new commands are found."
  for id in $RESOLVED_TOOLS; do
    case $(tool "$id" kind) in app) say "  - Open $(tool "$id" name) and sign in." ;; esac
  done
  in_list claude-code "$RESOLVED_TOOLS" && say "  - Run 'claude' once in a terminal and sign in."
  [ -n "$SEL_PLUGINS" ] && say "  - In Claude Code, run /reload-plugins or restart it to load the plugins."
  [ -z "$failed" ]
}

# ---------------------------------------------------------------- update

cmd_update() {
  local id rc v changed=0
  while [ $# -gt 0 ]; do
    case $1 in --yes|-y) export CGP_ASSUME_YES=1 ;; *) die "Unknown option '$1'" ;; esac
    shift
  done
  require_macos
  env_init
  sel_exists || die "No setup found. Run 'cgp-ai setup' first."
  sel_load; sel_resolve
  has_brew || die "Homebrew is missing. Run 'cgp-ai setup'."

  heading "Updating Homebrew's package list"
  brew update --quiet || warn "brew update failed; using the package list Homebrew already has"

  heading "Tools"
  for id in $RESOLVED_TOOLS; do
    if ! tool_present "$id"; then
      warn "$(tool "$id" name) is missing. Run 'cgp-ai setup'."; continue
    fi
    if [ "$(tool "$id" self_updates)" = "true" ]; then
      ok "$(tool "$id" name) $(tool_version "$id") (updates itself)"; continue
    fi
    tool_upgrade "$id"; rc=$?
    case $rc in
      0) changed=1; ok "$(tool "$id" name) updated to $(tool_version "$id")" ;;
      2) ok "$(tool "$id" name) $(tool_version "$id") (current)" ;;
      3) ok "$(tool "$id" name) $(tool_version "$id") (installed outside Homebrew, not touched)" ;;
      *) fail "$(tool "$id" name) could not be updated" ;;
    esac
  done

  if [ -n "$SEL_PLUGINS" ] && has_claude && marketplace_present; then
    heading "Plugins"
    marketplace_update >/dev/null 2>&1 || warn "Could not refresh the marketplace"
    for id in $SEL_PLUGINS; do
      plugin_present "$id" || { warn "Plugin $(plugin "$id" name) is missing. Run 'cgp-ai setup'."; continue; }
      v=$(plugin_version "$id")
      plugin_update "$id" >/dev/null 2>&1 || { fail "Plugin $(plugin "$id" name) could not be updated"; continue; }
      if [ "$(plugin_version "$id")" != "$v" ]; then changed=1; ok "Plugin $(plugin "$id" name) updated to $(plugin_version "$id")"
      else ok "Plugin $(plugin "$id" name) $v (current)"; fi
    done
  fi

  say ""
  if [ "$changed" = "1" ]; then say "Updated. Restart Claude Code to load new plugin versions."
  else say "Everything was already current."; fi
}

# ---------------------------------------------------------------- doctor

cmd_doctor() {
  local id problems=0 paths n
  require_macos
  env_init
  heading "cgp-ai doctor"
  say "  macOS $(sw_vers -productVersion), $(uname -m), cgp-ai $(cgp_version)"

  heading "Basics"
  if has_brew; then ok "Homebrew $(brew --version 2>/dev/null | head -n 1 | awk '{print $2}')"
  else fail "Homebrew is missing"; hint "Fix: cgp-ai setup"; problems=$((problems + 1)); fi
  if grep -qs "brew shellenv" "$HOME/.zprofile" "$HOME/.zshrc" "$HOME/.bash_profile"; then ok "Homebrew is on the PATH of new terminals"
  elif has_brew; then warn "New terminals may not find Homebrew"; hint "Fix: echo 'eval \"\$($BREW_PREFIX/bin/brew shellenv)\"' >> ~/.zprofile"; fi

  if ! sel_exists; then
    warn "No saved selection. Run 'cgp-ai setup' to choose a profile."
    say ""; return 1
  fi
  sel_load; sel_resolve
  ok "Selection: $SEL_PROFILE"

  heading "Tools"
  for id in $RESOLVED_TOOLS; do
    if tool_present "$id"; then ok "$(tool "$id" name) $(tool_version "$id")"
    else fail "$(tool "$id" name) is missing"; hint "Fix: cgp-ai setup"; problems=$((problems + 1)); fi
  done

  # The same command installed twice: the PATH decides which one starts.
  for id in claude codex; do
    paths=$(which -a "$id" 2>/dev/null | awk '!seen[$0]++')
    n=$(printf '%s\n' "$paths" | grep -c .)
    if [ "$n" -gt 1 ]; then
      warn "'$id' is installed $n times; this one starts: $(printf '%s\n' "$paths" | head -n 1)"
      printf '%s\n' "$paths" | while IFS= read -r v; do hint "$v"; done
      problems=$((problems + 1))
    fi
  done
  if in_list claude-code "$RESOLVED_TOOLS" && has_brew && brew list --cask "$(tool claude-code mac.conflicts_cask)" >/dev/null 2>&1; then
    warn "Claude Code is also installed through Homebrew; that copy does not update itself"
    hint "Fix: brew uninstall --cask $(tool claude-code mac.conflicts_cask)"
  fi

  if in_list docker-desktop "$RESOLVED_TOOLS" && tool_present docker-desktop; then
    if docker info >/dev/null 2>&1; then ok "Docker is running"
    else warn "Docker is installed but not running"; hint "Open Docker from Applications"; fi
  fi

  if [ -n "$SEL_PLUGINS" ]; then
    heading "Claude Code plugins"
    if ! has_claude; then fail "Claude Code CLI is missing"; hint "Fix: cgp-ai setup"; problems=$((problems + 1))
    elif marketplace_conflict; then
      fail "Another marketplace named '$(marketplace_name)' is set up"
      hint "Fix: claude plugin marketplace remove $(marketplace_name) && cgp-ai setup"
      problems=$((problems + 1))
    elif ! marketplace_present; then fail "Crypto Gameplan marketplace is not added"; hint "Fix: cgp-ai setup"; problems=$((problems + 1))
    else
      ok "Crypto Gameplan marketplace"
      for id in $SEL_PLUGINS; do
        if plugin_present "$id"; then ok "Plugin $(plugin "$id" name) $(plugin_version "$id")"
        else fail "Plugin $(plugin "$id" name) is missing"; hint "Fix: cgp-ai setup"; problems=$((problems + 1)); fi
      done
    fi
  fi

  say ""
  if [ "$problems" = "0" ]; then say "No problems found."; else say "$problems problem(s) found."; fi
  [ "$problems" = "0" ]
}
