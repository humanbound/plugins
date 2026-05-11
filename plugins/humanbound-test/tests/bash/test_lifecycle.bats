#!/usr/bin/env bats
# Lifecycle tests — config write, state file ops. Uses /tmp project dirs.

PLUGIN="${BATS_TEST_DIRNAME}/../.."

setup() {
  TMP="$(mktemp -d)"
  cd "$TMP"
}

teardown() {
  cd /
  rm -rf "$TMP"
}

@test "detect-server.py writes config.toml on a fastapi project" {
  cat > pyproject.toml <<EOF
[project]
name = "x"
dependencies = ["fastapi"]
EOF
  cat > main.py <<EOF
from fastapi import FastAPI
app = FastAPI()
EOF
  python3 "$PLUGIN/skills/tunneling-local-agent/scripts/detect-server.py" "$PWD" --write
  [ -f .humanbound/test/config.toml ]
  grep -q 'provider = "fastapi"' .humanbound/test/config.toml
}

@test "detect-server.py exits non-zero on a non-fastapi project" {
  cat > Makefile <<EOF
all:
	echo hi
EOF
  run python3 "$PLUGIN/skills/tunneling-local-agent/scripts/detect-server.py" "$PWD" --write
  [ "$status" -ne 0 ]
}

@test "prepare-bot-config.py writes a template on first call" {
  python3 "$PLUGIN/skills/dispatching-hb-tests/scripts/prepare-bot-config.py" \
    prepare "$PWD" "https://abc-123.ngrok-free.app"
  [ -f .humanbound/test/bot-config.json ]
  grep -q '"streaming": false' .humanbound/test/bot-config.json
  grep -q '<your-chat-path>' .humanbound/test/bot-config.json
}

@test "prepare-bot-config.py refreshes ngrok URL on second call" {
  mkdir -p .humanbound/test
  cat > .humanbound/test/bot-config.json <<EOF
{
  "streaming": false,
  "chat_completion": {
    "endpoint": "https://OLD-host.ngrok-free.app/chat",
    "headers": {"x-api-key": "sk-test"},
    "payload": {"message": "\$PROMPT"}
  },
  "thread_init": {"endpoint": "", "headers": {}, "payload": {}}
}
EOF
  python3 "$PLUGIN/skills/dispatching-hb-tests/scripts/prepare-bot-config.py" \
    prepare "$PWD" "https://new-host.ngrok-free.app"
  grep -q '"endpoint": "https://new-host.ngrok-free.app/chat"' .humanbound/test/bot-config.json
  grep -q '"x-api-key": "sk-test"' .humanbound/test/bot-config.json
}

@test "prepare-bot-config.py validate passes on a filled config" {
  mkdir -p .humanbound/test
  cat > .humanbound/test/bot-config.json <<EOF
{
  "chat_completion": {
    "endpoint": "https://abc.ngrok-free.app/chat",
    "headers": {},
    "payload": {"message": "\$PROMPT"}
  }
}
EOF
  python3 "$PLUGIN/skills/dispatching-hb-tests/scripts/prepare-bot-config.py" \
    validate "$PWD"
}

@test "paths.sh resolves project-local state directories" {
  PROJECT="$PWD" bash -c "source $PLUGIN/scripts/lib/paths.sh && [ \"\$HB_TEST_STATE_DIR\" = \"$PWD/.humanbound/test\" ]"
  PROJECT="$PWD" bash -c "source $PLUGIN/scripts/lib/paths.sh && [ \"\$HB_TEST_SECRETS_DIR\" = \"$PWD/.humanbound/test/secrets\" ]"
  PROJECT="$PWD" bash -c "source $PLUGIN/scripts/lib/paths.sh && [ \"\$HB_TEST_LOG_DIR\" = \"$PWD/.humanbound/test/logs\" ]"
}
