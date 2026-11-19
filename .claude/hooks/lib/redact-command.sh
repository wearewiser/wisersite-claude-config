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
  # Covers -H / --header with any separator (=, whitespace, or none when
  # the value is attached to a quote), and raw header forms anywhere in
  # the command. The bare rule consumes an optional scheme word (Bearer,
  # Basic, token, etc) before the value so a token containing `/` or `+`
  # is still captured in full after the scheme is matched.
  s/((?:-H|--header)\s*=?\s*["\x27]?)(Authorization|X-API-Key|x-goog-api-key|Cookie|Private-Token)(\s*:\s*)[^"\x27\n]+/${1}${2}${3}[redacted]/gi;
  s/\b(Authorization|X-API-Key|x-goog-api-key|Cookie|Private-Token)(\s*:\s*)(?:[A-Za-z]+\s+)?[^\s"\x27,;]+/${1}${2}[redacted]/gi;

  # Bearer token form. Runs after the header rule so headers that
  # already carried Bearer tokens are folded into the header redaction
  # first; this catches Bearer tokens anywhere else in the command.
  # \S+ (not a restricted char class) so base64 / OAuth / JWT tokens
  # containing / or + or ~ are captured in full.
  s/\bBearer\s+\S+/Bearer [redacted]/gi;

  # curl -u user:pass form. Handles quoted argument too, so a password
  # containing whitespace does not leak its suffix after the first space.
  # Scoped to curl / wget contexts so a general -u flag (mysql username,
  # ssh user, etc) in other commands is not touched.
  s/(\b(?:curl|wget)\b[^\n]*?\s-u\s+)(?:(["\x27])(?:\\.|(?!\2)[\s\S])*\2|[^\s]+)/${1}[redacted]/g;

  # Flag forms: --password, --token, --secret, --api-key, --auth, --credential.
  # Separator accepts = or one-or-more whitespace characters, so repeated
  # spaces between flag and value do not bypass. Quoted body handles
  # backslash-escaped quotes in both styles so a value like first then
  # backslash-quote tail is consumed in full; the unquoted branch is only
  # tried when no quote follows the separator.
  s/(--(?:password|token|secret|api[\-_]?key|auth|credential)(?:=|\s+))(?:(["\x27])(?:\\.|(?!\2)[\s\S])*\2|[^\s"\x27]+)/${1}[redacted]/gi;

  # MySQL attached short-form password: -pPASSWORD (never -p<space>PASSWORD,
  # which mysql treats as a prompt). Scoped to mysql / mysqldump contexts
  # so a general -p flag (port, path) in other commands is not touched.
  # Quoted-body alternative handles -p"my pass" without leaking the tail
  # after the first space; the unquoted branch stops at command
  # separators so `-psecret; ls` keeps its `;`.
  s/(\bmysql(?:dump)?\b[^\n]*?\s)-p(?:(["\x27])(?:\\.|(?!\2)[\s\S])*\2|[^\s;&|]+)/${1}-p[redacted]/gi;

  # JSON embedded in shell: "key":"value" where key contains a keyword.
  # Value body accepts backslash-escaped characters so an escaped quote
  # (\") inside the string does not end the match prematurely.
  s/("(?:[A-Za-z_\-]*(?:token|secret|key|password|pass|auth|credential|api[_\-]?key)[A-Za-z_\-]*)"\s*:\s*)"(?:\\.|[^"])*"/${1}"[redacted]"/gi;

  # KEY=value env assignments where the name contains a keyword anywhere,
  # or IS the keyword itself. \w* zero-or-more on either side matches
  # bare TOKEN / SECRET / KEY as well as GITHUB_TOKEN / AWS_SECRET_ACCESS_KEY.
  # Quoted (any quote style) first, then unquoted. Quoted body uses
  # [\s\S] rather than . so multi-line values across heredocs do not
  # slip through; backslash-escaped characters are consumed whole so an
  # escaped quote inside the value does not terminate the match.
  s/(\b\w*(?:TOKEN|SECRET|KEY|PASSWORD|PASS|AUTH|CREDENTIAL|API_KEY|DATABASE_URL)\w*\s*=\s*)(["\x27])(?:\\.|(?!\2)[\s\S])*\2/${1}${2}[redacted]${2}/gi;
  s/(\b\w*(?:TOKEN|SECRET|KEY|PASSWORD|PASS|AUTH|CREDENTIAL|API_KEY|DATABASE_URL)\w*\s*=\s*)(?!["\x27])[^\s;&|"\x27]+/${1}[redacted]/gi;
'
