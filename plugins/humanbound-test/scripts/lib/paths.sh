#!/usr/bin/env bash
# paths.sh — resolves state / log directories under the project root.
# Sources before any other lib that touches the filesystem.
# Inputs:  PROJECT (absolute path; defaults to $PWD).
# Outputs (exported):
#   HB_TEST_STATE_DIR     — <project>/.humanbound/test
#   HB_TEST_LOG_DIR       — <project>/.humanbound/test/logs
#   HB_TEST_PROJECT_HASH  — short SHA of $PROJECT (12 chars; kept for log filenames)
#
# All state is always project-local — no user-home fallback. Add `.humanbound/`
# to your `.gitignore` (the plugin appends it automatically on first run).
set -euo pipefail

: "${PROJECT:=$(pwd)}"

HB_TEST_PROJECT_HASH="$(printf '%s' "$PROJECT" | shasum -a 256 | cut -c1-12)"

HB_TEST_STATE_DIR="$PROJECT/.humanbound/test"
HB_TEST_LOG_DIR="$HB_TEST_STATE_DIR/logs"

mkdir -p "$HB_TEST_STATE_DIR" "$HB_TEST_LOG_DIR"

export HB_TEST_STATE_DIR HB_TEST_LOG_DIR HB_TEST_PROJECT_HASH
