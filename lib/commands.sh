# setup, update and doctor.

require_macos() {
  [ "$(uname -s)" = "Darwin" ] || die "This version of cgp-ai runs on macOS. Windows follows."
}

_note_reason() {
  # Why a tool is in the plan although the person did not pick it.
  in_list "$1" "$SEL_TOOLS" && return
  printf ' (needed by your selection)'
}

_provider_label() {
  case $SEL_PROVIDER in
    claude) printf 'Claude' ;;
    openai) printf 'ChatGPT and Codex' ;;
    *)      printf 'Claude, ChatGPT and Codex' ;;
  esac
}

# ---------------------------------------------------------------- setup

cmd_setup() {
  local dry=0 change=0 want_profile="" want_provider="" id v
  local missing_tools="" missing_plugins="" failed="" need_brew=0 need_market=0 open_items
  while [ $# -gt 0 ]; do
    case $1 in
      --dry-run) dry=1 ;;
      --change)  change=1 ;;
      --yes|-y)  export CGP_ASSUME_YES=1 ;;
      --profile) shift; want_profile=${1:-} ;;
      --profile=*) want_profile=${1#--profile=} ;;
      --ai) shift; want_provider=${1:-} ;;
      --ai=*) want_provider=${1#--ai=} ;;
      --with) shift; SEL_WITH=$(add_line "$SEL_WITH" "${1:-}") ;;
      --with=*) SEL_WITH=$(add_line "$SEL_WITH" "${1#--with=}") ;;
      *) die "Unknown option '$1'. See: cgp-ai help" ;;
    esac
    shift
  done

  require_macos
  env_init
  heading "cgp-ai $(cgp_version) on macOS $(sw_vers -productVersion) ($(uname -m))"

  # Selection: saved, from options, or asked
  if [ -z "$want_profile$want_provider" ] && sel_exists && [ "$change" = "0" ]; then
    sel_load
    say "Using your saved selection: $(_provider_label), profile $SEL_PROFILE. Run 'cgp-ai setup --change' to choose again."
  else
    sel_exists && { sel_load; SEL_TOOLS=""; SEL_PLUGINS=""; }   # keeps sign-ins you confirmed
    if [ -n "$want_provider" ]; then sel_set_provider "$want_provider"
    elif [ -n "$want_profile" ]; then SEL_PROVIDER=both
    else sel_ask_provider; fi
    if [ "$want_profile" = "custom" ]; then sel_custom
    elif [ -n "$want_profile" ]; then sel_from_profile "$want_profile"
    else sel_ask_profile; fi
  fi
  for id in $SEL_WITH; do
    in_list "$id" "$SEL_TOOLS" || warn "--with $id does not fit this selection and is ignored"
  done
  sel_resolve

  # Plan
  heading "Plan for $(_provider_label)"
  has_brew || { need_brew=1; todo "Homebrew: will be installed (needed for everything else)"; }
  for id in $RESOLVED_TOOLS; do
    if tool_present "$id"; then
      v=$(tool_version "$id"); ok "$(tool "$id" name)${v:+ $v}"
    else
      todo "$(tool "$id" name): will be installed via $(tool_route "$id")$(_note_reason "$id")"
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
  hint "Afterwards cgp-ai walks you through signing in to each app and tool."

  if [ "$dry" = "1" ]; then
    say ""; say "Dry run: nothing was changed."; return 0
  fi

  # Install
  if [ "$need_brew$need_market" != "00" ] || [ -n "$missing_tools$missing_plugins" ]; then
    say ""
    ask_yn "Install the items marked +?" y || { say "Nothing was changed."; return 0; }
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
  fi
  sel_save

  # Sign-ins and first starts
  open_items=$(finish_open)
  if [ -n "$open_items" ] && interactive; then
    heading "Signing in"
    say "  cgp-ai opens each app or starts each sign-in. You sign in yourself; cgp-ai never sees your login."
    for id in $open_items; do finish_run "$id"; done
    sel_save
  fi

  # Status
  heading "Status"
  for id in $RESOLVED_TOOLS; do
    if ! tool_present "$id"; then fail "$(tool "$id" name): not installed"
    elif has_finish "$id"; then finish_line "$id"
    else ok "$(tool "$id" name)"; fi
  done
  for id in $SEL_PLUGINS; do
    if plugin_present "$id"; then ok "Plugin $(plugin "$id" name)"; else fail "Plugin $(plugin "$id" name): not installed"; fi
  done

  open_items=$(finish_open)
  say ""
  if [ -z "$failed" ] && [ -z "$open_items" ]; then
    printf '%s✓ All set.%s Everything is installed and signed in. You can start working.\n' "$C_GREEN$C_BOLD" "$C_RESET"
    say "  Open a new terminal window so the new commands are found."
    [ -n "$SEL_PLUGINS" ] && say "  If Claude Code was already open, run /reload-plugins in it."
    return 0
  fi
  printf '%sNot finished yet.%s The items marked ✗ above still need you.\n' "$C_YELLOW$C_BOLD" "$C_RESET"
  say "  Run 'cgp-ai setup' again to continue, or 'cgp-ai doctor' to check everything."
  [ -n "$failed" ] && say "  If an installation keeps failing, post the output of 'cgp-ai doctor' in the CGP AI Lab."
  return 1
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
  local id problems=0 paths n v
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
    warn "No saved selection. Run 'cgp-ai setup' to choose your AI and profile."
    say ""; return 1
  fi
  sel_load; sel_resolve
  ok "Selection: $(_provider_label), profile $SEL_PROFILE"

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

  heading "Sign-ins and first starts"
  for id in $RESOLVED_TOOLS; do
    if ! tool_present "$id" || ! has_finish "$id"; then continue; fi
    finish_line "$id"
    if [ "$(finish_state "$id")" = "open" ]; then
      problems=$((problems + 1))
      v=$(tool "$id" finish.command)
      if [ -n "$v" ]; then hint "Fix: $v"; else hint "Fix: cgp-ai setup"; fi
    fi
  done

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
  if [ "$problems" = "0" ]; then printf '%s✓ All set.%s No problems found.\n' "$C_GREEN$C_BOLD" "$C_RESET"
  else say "$problems problem(s) found."; fi
  [ "$problems" = "0" ]
}
