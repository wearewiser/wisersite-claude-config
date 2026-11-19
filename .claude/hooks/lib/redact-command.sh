#!/usr/bin/env bash
# Redacts secrets from a shell command string. Reads stdin, writes the
# redacted string to stdout. Rules pinned in schemas/activity_log.md.
#
# Multi-line safe (perl -0777 slurp) so heredoc bodies are covered.
# Order of rules is load-bearing: private-key blocks first (they span
# lines and could otherwise be chopped by other patterns), then
# known-prefix tokens, then structural forms (URL creds, headers,
# flags, JSON), then keyword env assignments last (they are the
# broadest and should not match earlier redactions).
#
# Backreferences in replacements always use ${N} rather than $N when
# followed by a `[`; bare `$1[redacted]` is parsed by perl as an array
# subscript on @1 and silently eats the surrounding content.

perl -0777 -pe '
  # Private-key blocks (multi-line). Label (RSA, EC, OPENSSH, etc) is
  # optional so unlabelled PKCS#8 blocks are also caught.
  s/-----BEGIN (?:[A-Z ]+)?PRIVATE KEY-----[\s\S]*?-----END (?:[A-Z ]+)?PRIVATE KEY-----/[redacted-private-key]/g;

  # Known-prefix tokens. sk- requires a word boundary and min 20 chars
  # of suffix so task-, disk-, and similar substrings are not caught.
  s/\bsk-[A-Za-z0-9_\-]{20,}/sk-[redacted]/g;
  # GitHub token family: p=classic PAT, o=OAuth app, u=user-to-server,
  # s=server-to-server, r=refresh. github_pat_ handles fine-grained PATs.
  s/\bgh[pousr]_[A-Za-z0-9_]+/gh[redacted]/g;
  s/\bgithub_pat_[A-Za-z0-9_]+/github_pat_[redacted]/g;
  # GitLab personal access tokens.
  s/\bglpat-[A-Za-z0-9_\-]+/glpat-[redacted]/g;
  # npm auth tokens.
  s/\bnpm_[A-Za-z0-9_]+/npm_[redacted]/g;
  # Stripe secret / restricted keys, live and test.
  s/\b(?:sk|rk)_(?:live|test)_[A-Za-z0-9_]+/[redacted]/gi;
  s/\bxox[A-Za-z]-[A-Za-z0-9\-]+/xox[redacted]/g;
  s/\bAKIA[A-Z0-9]{16}/AKIA[redacted]/g;
  s/\bAIza[A-Za-z0-9_\-]+/AIza[redacted]/g;
  s/\bya29\.[A-Za-z0-9_\-]+/ya29.[redacted]/g;
  s/\bGOCSPX-[A-Za-z0-9_\-]+/GOCSPX-[redacted]/g;
  s/\beyJ[A-Za-z0-9_\-\.]{20,}/eyJ[redacted]/g;

  # URL credentials: scheme://user:pass@host.
  s/([a-z][a-z0-9+.\-]*:\/\/)[^\s:@\/]+:[^\s@\/]+@/${1}[redacted]@/gi;

  # Headers: Authorization, X-API-Key, x-goog-api-key, Cookie, Private-Token.
  # Split by wrapper style so the value body terminates on the MATCHING
  # wrapper only (a single-quoted wrapper carrying a double-quoted
  # inner value used to leak and vice versa). For each wrapper there
  # is an extended rule (closing wrapper followed by one-or-more
  # adjacent shell fragments; handles the -H wrapper+concat leak case)
  # and a standard rule (closing wrapper followed by shell separator
  # or end-of-string; preserves the closing quote in the output).
  # Extended rules run BEFORE standard rules so the standard rule only
  # matches when there is no trailing fragment to consume.
  # Extended double-quoted.
  s/((?:-H|--header)(?:=|\s*))"(Authorization|X-API-Key|x-goog-api-key|Cookie|Private-Token)(\s*:\s*)(?:\\.|[^"])+"(?:"(?:\\.|[^"])*"|\x27[^\x27]*\x27|\\.|[^\s;&|"\x27\\])+/${1}"${2}${3}[redacted]/gi;
  # Extended single-quoted.
  s/((?:-H|--header)(?:=|\s*))\x27(Authorization|X-API-Key|x-goog-api-key|Cookie|Private-Token)(\s*:\s*)[^\x27]+\x27(?:"(?:\\.|[^"])*"|\x27[^\x27]*\x27|\\.|[^\s;&|"\x27\\])+/${1}\x27${2}${3}[redacted]/gi;
  # Standard double-quoted wrapper. Require a closing " in the match
  # so this rule does NOT try to redact a half-open wrapper left
  # behind by the extended rule above (no closing " to anchor on,
  # the body would run to end of input and eat the rest of the
  # command). Closing " is restored in the replacement.
  s/((?:-H|--header)(?:=|\s*)")(Authorization|X-API-Key|x-goog-api-key|Cookie|Private-Token)(\s*:\s*)(?:\\.|[^"])+"/${1}${2}${3}[redacted]"/gi;
  # Standard single-quoted wrapper. Same closing-quote anchor.
  s/((?:-H|--header)(?:=|\s*)\x27)(Authorization|X-API-Key|x-goog-api-key|Cookie|Private-Token)(\s*:\s*)[^\x27]+\x27/${1}${2}${3}[redacted]\x27/gi;
  # Unquoted header arg: the whole header is passed as one shell word
  # with no outer wrapper. Shell-token value matcher consumes adjacent
  # fragments and escape-whitespace (-H Cookie:\ session=TAIL) rather
  # than stopping at the first literal space.
  s/((?:-H|--header)(?:=|\s+))(?!["\x27])(Authorization|X-API-Key|x-goog-api-key|Cookie|Private-Token)(\s*:\s*)(?:"(?:\\.|[^"])*"|\x27[^\x27]*\x27|\\.|[^\s;&|"\x27\\])+/${1}${2}${3}[redacted]/gi;
  # Bare header anywhere in the command (not inside -H/--header). The
  # bare rule consumes an optional scheme word (Bearer, Basic, token,
  # etc) before the value so a token containing `/` or `+` is still
  # captured in full after the scheme is matched.
  s/\b(Authorization|X-API-Key|x-goog-api-key|Cookie|Private-Token)(\s*:\s*)(?:[A-Za-z]+\s+)?[^\s"\x27,;]+/${1}${2}[redacted]/gi;

  # Bearer token form. Runs after the header rule so headers that
  # already carried Bearer tokens are folded into the header redaction
  # first; this catches Bearer tokens anywhere else in the command.
  # \S+ (not a restricted char class) so base64 / OAuth / JWT tokens
  # containing / or + or ~ are captured in full.
  s/\bBearer\s+\S+/Bearer [redacted]/gi;

  # Shell-token value matcher used by every flag/assignment rule below.
  # Consumes one or more adjacent fragments where each fragment is a
  # double-quoted string (treating backslash-anything as one unit so
  # escaped quotes inside do not end the fragment), a single-quoted
  # string (no escape processing, like real shell), an escaped
  # character outside quotes (so KEY=foo\ bar consumes the whole shell
  # word), or a plain non-separator char. Catches adjacent-fragment
  # assignments, escaped-whitespace values, and attached -p forms all
  # in one expression.

  # curl / wget credentials. Short `-u` supports the attached form
  # `-uuser:pass` (curl convention), so the separator after `-u` is
  # `=`, whitespace, or empty. Long `--user` requires `=` or whitespace
  # so an unrelated flag like `--useragent` (hypothetical) will not
  # swallow its tail.
  s/(\b(?:curl|wget)\b[^\n]*?\s(?:-u(?:=|\s*)|--user(?:=|\s+)))(?:"(?:\\.|[^"])*"|\x27[^\x27]*\x27|\\.|[^\s;&|"\x27\\])+/${1}[redacted]/g;

  # Standalone -u / --user with user:password shape, used to catch
  # repeated credential options in curl --next chains (the scoped rule
  # above only redacts the first -u in a command because its
  # curl|wget anchor is consumed on the first iteration). The required
  # colon in the value discriminates from `mysql -u root` style bare
  # usernames so this rule stays out of their way.
  s/(\s(?:-u(?:=|\s*)|--user(?:=|\s+)))(?:"(?:\\.|[^"])*:(?:\\.|[^"])*"|\x27[^\x27]*:[^\x27]*\x27|[^\s;&|"\x27\\]+:[^\s;&|"\x27\\]+)/${1}[redacted]/g;

  # Flag forms: --password, --token, --secret, --api-key, --auth, --credential.
  # Separator accepts = or one-or-more whitespace characters, so repeated
  # spaces between flag and value do not bypass.
  s/(--(?:password|token|secret|api[\-_]?key|auth|credential)(?:=|\s+))(?:"(?:\\.|[^"])*"|\x27[^\x27]*\x27|\\.|[^\s;&|"\x27\\])+/${1}[redacted]/gi;

  # MySQL attached short-form password: -pPASSWORD (never -p<space>PASSWORD,
  # which mysql treats as a prompt). Scoped to mysql / mysqldump contexts
  # so a general -p flag (port, path) in other commands is not touched.
  # Unquoted branch stops at command separators so `-psecret; ls` keeps
  # its `;`.
  s/(\bmysql(?:dump)?\b[^\n]*?\s)-p(?:"(?:\\.|[^"])*"|\x27[^\x27]*\x27|\\.|[^\s;&|"\x27\\])+/${1}-p[redacted]/gi;

  # JSON embedded in shell: "key":"value" where key contains a keyword.
  # Value body accepts backslash-escaped characters so an escaped quote
  # (\") inside the string does not end the match prematurely.
  s/("(?:[A-Za-z_\-]*(?:token|secret|key|password|pass|auth|credential|api[_\-]?key)[A-Za-z_\-]*)"\s*:\s*)"(?:\\.|[^"])*"/${1}"[redacted]"/gi;

  # Shell-escaped JSON: \"key\":\"value\" where the JSON is wrapped in
  # a double-quoted shell argument so every quote arrives at the hook
  # as \". Used by curl -d "{\"password\":\"...\"}" and equivalents;
  # the literal-quote JSON rule above does not match this form because
  # it expects raw quotes.
  s/(\\"(?:[A-Za-z_\-]*(?:token|secret|key|password|pass|auth|credential|api[_\-]?key)[A-Za-z_\-]*)\\"\s*:\s*)\\"(?:\\.|[^\\"])*\\"/${1}\\"[redacted]\\"/gi;

  # KEY=value env assignments where the name contains a keyword anywhere,
  # or IS the keyword itself. \w* zero-or-more on either side matches
  # bare TOKEN / SECRET / KEY as well as GITHUB_TOKEN / AWS_SECRET_ACCESS_KEY.
  #
  # Rule A (quote-preserving): value is a single quoted span terminated
  # by whitespace / shell separator / end-of-string. Preserves the
  # surrounding quote char so logs stay readable (KEY="[redacted]").
  # The lookahead stops Rule A from firing when the quoted span is
  # concatenated with an adjacent fragment of a different quote style;
  # in that case control falls to Rule B which eats the whole value.
  s/(\b\w*(?:TOKEN|SECRET|KEY|PASSWORD|PASS|AUTH|CREDENTIAL|API_KEY|DATABASE_URL)\w*\s*=\s*)(["\x27])(?:\\.|(?!\2)[\s\S])*\2(?=[\s;&|]|$)/${1}${2}[redacted]${2}/gi;
  #
  # Rule B (all other shapes): bare values, escaped whitespace
  # (KEY=foo\ bar), adjacent quoted fragments of mixed styles, and
  # mixed quoted/unquoted concat (KEY="first"second). Negative
  # lookahead skips a value Rule A has already redacted so the quote
  # chars Rule A preserved are not stripped on the second pass.
  s/(\b\w*(?:TOKEN|SECRET|KEY|PASSWORD|PASS|AUTH|CREDENTIAL|API_KEY|DATABASE_URL)\w*\s*=\s*)(?!["\x27]?\[redacted\]["\x27]?)(?:"(?:\\.|[^"])*"|\x27[^\x27]*\x27|\\.|[^\s;&|"\x27\\])+/${1}[redacted]/gi;
'
