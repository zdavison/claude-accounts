# Shared helpers for the resolver and the claude-accounts CLI, so both read the config the same way.

# Expand ~ and drop trailing slashes
def norm:
  (if . == "~" then $ENV.HOME elif startswith("~/") then $ENV.HOME + .[1:] else . end)
  | if . == "/" then . else sub("/+$"; "") end;

# Is this path $d or below it?
def within($d): . == $d or startswith(if $d == "/" then "/" else $d + "/" end);

def overlaps($d): . as $x | ($x | within($d)) or ($d | within($x));

# The configured accounts with defaults filled in and paths normalized
def accounts:
  . as $c
  | [ (.accounts // {}) | to_entries[]
      | { name: .key,
          label: (.value.label // (.key | ascii_upcase)),
          emoji: (.value.emoji // "🔵"),
          configDir: ((.value.configDir // (if .key == $c.default then "~/.claude" else "~/.claude-" + .key end)) | norm),
          dirs: [ (.value.dirs // [])[] | norm ] } ];
