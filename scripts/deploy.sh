#!/usr/bin/env bash
set -euo pipefail

# Deploy blog to Aliyun server via rsync
# Usage: pnpm deploy [--dry-run]

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
SSH_HOST="${DEPLOY_HOST:-Aliyun}"
REMOTE_PATH="${DEPLOY_PATH:-/srv/blog}"

DRY_RUN=""
if [[ "${1:-}" == "--dry-run" ]]; then
  DRY_RUN="--dry-run"
  echo "🔍 Dry run mode — no files will be transferred"
fi

cd "$PROJECT_DIR"

echo "📦 Building..."
pnpm build

echo "📤 Deploying to ${SSH_HOST}:${REMOTE_PATH} ..."
rsync -avz --delete $DRY_RUN dist/ "${SSH_HOST}:${REMOTE_PATH}/"

if [[ -z "$DRY_RUN" ]]; then
  echo "✅ Deployed: https://lorenzofeng.top/"
fi
