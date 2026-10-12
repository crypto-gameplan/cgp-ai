# Sign-ins and first starts. cgp-ai never handles credentials: it opens the
# app or runs the tool's own login command, and the person signs in there.
# A sign-in that can be checked (the CLIs, Docker) is checked; one that cannot
# (the desktop apps) is confirmed by the person and remembered.

has_finish() { [ -n "$(tool "$1" finish.label)" ]; }

# finish_state <id> -> verified | confirmed | open
finish_state() {
  local check
  check=$(tool "$1" finish.check)
  if [ -n "$check" ]; then
    if run_check "$check"; then echo verified; else echo open; fi
  elif sel_is_confirmed "$1"; then echo confirmed
  else echo open
  fi
}

# Can we ask the person to do something right now?
interactive() { [ "${CGP_ASSUME_YES:-0}" != "1" ] && ( : < /dev/tty ) 2>/dev/null; }

# finish_run <id>: walks the person through one sign-in or first start
finish_run() {
  local id=$1 cmd app check
  cmd=$(tool "$id" finish.command); app=$(tool "$id" finish.open); check=$(tool "$id" finish.check)
  heading "$(tool "$id" finish.label)"
  say "  $(tool "$id" finish.how)"
  if [ -n "$cmd" ]; then
    ask_yn "  Start the sign-in now?" y || return
    bash -c "$cmd" < /dev/tty
  else
    [ -n "$app" ] && open -a "$app" 2>/dev/null
    if [ -n "$check" ]; then
      ask_yn "  Done?" y || return
    else
      ask_yn "  Have you signed in?" y && sel_confirm "$id"
      return
    fi
  fi
  [ "$(finish_state "$id")" = "open" ] && warn "Not done yet. You can run 'cgp-ai setup' again later to finish it."
}

finish_line() {
  case $(finish_state "$1") in
    verified)  ok "$(tool "$1" finish.label): done" ;;
    confirmed) ok "$(tool "$1" finish.label): done (you confirmed it; apps cannot be checked automatically)" ;;
    *)         fail "$(tool "$1" finish.label): still open"; hint "$(tool "$1" finish.how)" ;;
  esac
}

# Prints the open items of the resolved tools, one per line.
finish_open() {
  local id
  for id in $RESOLVED_TOOLS; do
    tool_present "$id" && has_finish "$id" && [ "$(finish_state "$id")" = "open" ] && echo "$id"
  done
}
