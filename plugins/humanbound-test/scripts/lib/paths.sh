#!/usr/bin/env bash
# paths.sh — resolves state / log / secret directories under the project root.
# Sources before any other lib that touches the filesystem.
# Inputs:  PROJECT (absolute path; defaults to $PWD).
# Outputs (exported):
#   HB_TEST_STATE_DIR     — <project>/.humanbound/test
#   HB_TEST_LOG_DIR       — <project>/.humanbound/test/logs
#   HB_TEST_SECRETS_DIR   — <project>/.humanbound/test/secrets
#   HB_TEST_SECRETS_FILE  — <project>/.humanbound/test/secrets/secrets.json
#   HB_TEST_PROJECT_HASH  — short SHA of $PROJECT (12 chars; kept for log filenames)
#
# All state is always project-local — no user-home fallback. Add `.humanbound/`
# to your `.gitignore` (the plugin appends it automatically on first run).
set -euo pipefail

: "${PROJECT:=$(pwd)}"

HB_TEST_PROJECT_HASH="$(printf '%s' "$PROJECT" | shasum -a 256 | cut -c1-12)"

HB_TEST_STATE_DIR="$PROJECT/.humanbound/test"
HB_TEST_LOG_DIR="$HB_TEST_STATE_DIR/logs"
HB_TEST_SECRETS_DIR="$HB_TEST_STATE_DIR/secrets"
HB_TEST_SECRETS_FILE="$HB_TEST_SECRETS_DIR/secrets.json"

mkdir -p "$HB_TEST_STATE_DIR" "$HB_TEST_LOG_DIR" "$HB_TEST_SECRETS_DIR"
chmod 700 "$HB_TEST_SECRETS_DIR" 2>/dev/null || true

export HB_TEST_STATE_DIR HB_TEST_LOG_DIR HB_TEST_SECRETS_DIR HB_TEST_SECRETS_FILE HB_TEST_PROJECT_HASH
