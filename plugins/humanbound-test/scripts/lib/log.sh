#!/usr/bin/env bash
# log.sh (humanbound-test) — consistent leveled logging to stderr, plus a token redactor.

log_info()  { printf '[INFO] %s\n'  "$*" >&2; }
log_warn()  { printf '[WARN] %s\n'  "$*" >&2; }
log_error() { printf '[ERROR] %s\n' "$*" >&2; }

# log_redact: read stdin, replace sensitive tokens with ***.
# Redacts:
#   - Ngrok tokens: 2<26+ alnum chars>_<26+ alnum chars>
#   - Bearer tokens: Bearer [A-Za-z0-9_\-\.]+
#   - client_secret JSON values: "client_secret":"..."
log_redact() {
  sed -E \
    -e 's/2[A-Za-z0-9]{20,}_[A-Za-z0-9]{20,}/***REDACTED***/g' \
    -e 's/Bearer [A-Za-z0-9_\-\.]+/Bearer ***/g' \
    -e 's/"client_secret"[[:space:]]*:[[:space:]]*"[^"]+"/"client_secret":"***"/g'
}
