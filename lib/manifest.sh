# Reads manifest.json with plutil, which every Mac has; no jq or Python needed.

# m_get <key.path> -> value, or nothing if the key does not exist
m_get() { plutil -extract "$1" raw -o - "$MANIFEST" 2>/dev/null; }

# m_count <key.path> -> number of items in an array (0 if missing)
m_count() { local n; n=$(m_get "$1"); printf '%s' "${n:-0}"; }

# m_list <key.path> -> one array item per line
m_list() {
  local i n
  n=$(m_count "$1")
  i=0
  while [ "$i" -lt "$n" ]; do m_get "$1.$i"; i=$((i + 1)); done
}

# _index <array> <id> -> position of the item with that id
_index() {
  local i n
  n=$(m_count "$1")
  i=0
  while [ "$i" -lt "$n" ]; do
    if [ "$(m_get "$1.$i.id")" = "$2" ]; then printf '%s' "$i"; return 0; fi
    i=$((i + 1))
  done
  return 1
}

tool_ids()    { local i n; n=$(m_count tools); i=0; while [ "$i" -lt "$n" ]; do m_get "tools.$i.id"; i=$((i + 1)); done; }
plugin_ids()  { local i n; n=$(m_count plugins); i=0; while [ "$i" -lt "$n" ]; do m_get "plugins.$i.id"; i=$((i + 1)); done; }
profile_ids() { local i n; n=$(m_count profiles); i=0; while [ "$i" -lt "$n" ]; do m_get "profiles.$i.id"; i=$((i + 1)); done; }

# tool <id> <field.path>, plugin <id> <field>, profile <id> <field>
tool()    { local i; i=$(_index tools "$1") || return 1; m_get "tools.$i.$2"; }
plugin()  { local i; i=$(_index plugins "$1") || return 1; m_get "plugins.$i.$2"; }
profile() { local i; i=$(_index profiles "$1") || return 1; m_get "profiles.$i.$2"; }

tool_requires()    { local i; i=$(_index tools "$1") || return 1; m_list "tools.$i.requires"; }
profile_tools()    { local i; i=$(_index profiles "$1") || return 1; m_list "profiles.$i.tools"; }
profile_optional() { local i; i=$(_index profiles "$1") || return 1; m_list "profiles.$i.optional_tools"; }
profile_plugins()  { local i; i=$(_index profiles "$1") || return 1; m_list "profiles.$i.plugins"; }
plugin_requires()  { m_list plugin_requires; }

marketplace_name() { m_get marketplace.name; }
marketplace_repo() { m_get marketplace.repo; }
