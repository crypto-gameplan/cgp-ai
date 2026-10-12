# The Crypto Gameplan marketplace and its plugins in Claude Code.

has_claude() { command -v claude >/dev/null 2>&1; }

_marketplaces() { claude plugin marketplace list 2>/dev/null; }
_plugins()      { claude plugin list 2>/dev/null; }

marketplace_present() { has_claude && _marketplaces | grep -q "($(marketplace_repo))"; }

# A marketplace with our name that points somewhere else blocks adding ours.
marketplace_conflict() {
  has_claude || return 1
  _marketplaces | grep -q "❯ $(marketplace_name)\$" && ! marketplace_present
}

marketplace_add()    { claude plugin marketplace add "$(marketplace_repo)"; }
marketplace_update() { claude plugin marketplace update "$(marketplace_name)"; }

plugin_ref()     { printf '%s@%s' "$1" "$(marketplace_name)"; }
plugin_present() { has_claude && _plugins | grep -q "❯ $(plugin_ref "$1")\$"; }
plugin_install() { claude plugin install "$(plugin_ref "$1")"; }
plugin_update()  { claude plugin update "$(plugin_ref "$1")"; }

plugin_version() {
  _plugins | awk -v ref="❯ $(plugin_ref "$1")" '
    index($0, ref) { found = 1; next }
    found && /Version:/ { print $2; exit }'
}
