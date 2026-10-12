# Output and prompts. Prompts read from /dev/tty so they also work when the
# installer was started through `curl ... | bash`.

if [ -t 1 ] && [ -z "${NO_COLOR:-}" ]; then
  C_BOLD=$'\033[1m'; C_DIM=$'\033[2m'; C_RED=$'\033[31m'
  C_GREEN=$'\033[32m'; C_YELLOW=$'\033[33m'; C_RESET=$'\033[0m'
else
  C_BOLD=""; C_DIM=""; C_RED=""; C_GREEN=""; C_YELLOW=""; C_RESET=""
fi

say()     { printf '%s\n' "$*"; }
heading() { printf '\n%s%s%s\n' "$C_BOLD" "$*" "$C_RESET"; }
ok()      { printf '  %s✓%s %s\n' "$C_GREEN" "$C_RESET" "$*"; }
todo()    { printf '  %s+%s %s\n' "$C_YELLOW" "$C_RESET" "$*"; }
warn()    { printf '  %s!%s %s\n' "$C_YELLOW" "$C_RESET" "$*"; }
fail()    { printf '  %s✗%s %s\n' "$C_RED" "$C_RESET" "$*"; }
hint()    { printf '    %s%s%s\n' "$C_DIM" "$*" "$C_RESET"; }
die()     { printf '%sError:%s %s\n' "$C_RED" "$C_RESET" "$*" >&2; exit 1; }

# ask_yn "Question" default(y|n) -> returns 0 for yes
ask_yn() {
  local question=$1 default=${2:-n} answer prompt="[y/N]"
  [ "$default" = "y" ] && prompt="[Y/n]"
  if [ "${CGP_ASSUME_YES:-0}" = "1" ]; then return 0; fi
  if [ ! -r /dev/tty ]; then [ "$default" = "y" ]; return; fi
  printf '%s %s ' "$question" "$prompt" > /dev/tty
  read -r answer < /dev/tty || answer=""
  [ -z "$answer" ] && answer=$default
  case $answer in [yY]*) return 0 ;; *) return 1 ;; esac
}

# ask_choice "Question" max -> prints the chosen number (1..max)
ask_choice() {
  local question=$1 max=$2 answer
  [ -r /dev/tty ] || die "No terminal to ask in. Run with --profile <name>."
  while :; do
    printf '%s [1-%s] ' "$question" "$max" > /dev/tty
    read -r answer < /dev/tty || answer=""
    case $answer in
      ''|*[!0-9]*) ;;
      *) if [ "$answer" -ge 1 ] && [ "$answer" -le "$max" ]; then printf '%s' "$answer"; return; fi ;;
    esac
  done
}
