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

# Config problems that leave the account in use ambiguous: the resolver reports these as errors
def ambiguities:
  . as $c | accounts as $a
  | ( [ if any($a[]; .name == $c.default) then empty else "default account \"\($c.default)\" is not defined" end ]
    + [ $a[] as $x | $a[] | select(.name < $x.name and .configDir == $x.configDir) | "\(.name) and \($x.name) share config dir \(.configDir)" ]
    ) | .[];

# Every problem that makes a config unusable, one string each (the CLI refuses all of them;
# overlapping dirs still resolve by longest match, so only the CLI rejects those)
def problems:
  ambiguities,
  ( . as $c | accounts as $a
    | [ $a[] | .name as $n | .dirs[] | {n: $n, d: .} ] as $all
    | ( [ $a[] | select(.name == $c.default and (.dirs | length) > 0) | "the default account (\(.name)) cannot have dirs" ]
      + [ $all[] as $x | $all[] | select(.n < $x.n and (.d | overlaps($x.d))) | "\(.d) (\(.n)) overlaps \($x.d) (\($x.n))" ]
      ) | .[] );
