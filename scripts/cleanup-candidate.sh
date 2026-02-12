#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'USAGE'
Usage:
  scripts/cleanup-candidate.sh <candidate_slug> [options]

Options:
  --skip-render        Skip Render suspension/deletion
  --skip-db            Skip dropping Postgres schema
  --skip-repo          Skip archiving GitHub repo
  --suspend-only       Suspend Render service without deleting
  --help               Show this help

Required env vars:
  GITHUB_ORG
  RENDER_API_KEY
  RENDER_WORKSPACE_ID
  SHARED_DATABASE_URL_ADMIN

Optional env vars:
  DB_USER_PREFIX (default: eb_user_)
USAGE
}

require_env() {
  local name="$1"
  if [[ -z "${!name:-}" ]]; then
    echo "Missing required env var: $name" >&2
    exit 1
  fi
}

require_cmd() {
  local name="$1"
  if ! command -v "$name" >/dev/null 2>&1; then
    echo "Missing required command: $name" >&2
    exit 1
  fi
}

sanitize_slug() {
  echo "$1" | tr '[:upper:]' '[:lower:]' | sed -E 's/[^a-z0-9]+/_/g; s/^_+|_+$//g'
}

candidate_slug="${1:-}"
if [[ -z "$candidate_slug" ]]; then
  usage
  exit 1
fi
shift || true

skip_render=0
skip_db=0
skip_repo=0
suspend_only=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --skip-render)
      skip_render=1
      shift
      ;;
    --skip-db)
      skip_db=1
      shift
      ;;
    --skip-repo)
      skip_repo=1
      shift
      ;;
    --suspend-only)
      suspend_only=1
      shift
      ;;
    --help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown option: $1" >&2
      usage
      exit 1
      ;;
  esac
done

require_env GITHUB_ORG
require_env RENDER_API_KEY
require_env RENDER_WORKSPACE_ID
require_env SHARED_DATABASE_URL_ADMIN

require_cmd gh
require_cmd curl
require_cmd psql
require_cmd node

repo_name="emoji-battle-${candidate_slug}"
repo_full="${GITHUB_ORG}/${repo_name}"
schema_base="$(sanitize_slug "$candidate_slug")"
if [[ -z "$schema_base" ]]; then
  echo "Invalid candidate slug: $candidate_slug" >&2
  exit 1
fi
schema_name="eb_${schema_base}"
db_user_prefix="${DB_USER_PREFIX:-eb_user_}"
db_user="${db_user_prefix}${schema_base}"

if [[ "$skip_render" -eq 0 ]]; then
  echo "Locating Render service..."
  service_list="$(curl -sS -G \"https://api.render.com/v1/services\" \
    -H \"Authorization: Bearer ${RENDER_API_KEY}\" \
    --data-urlencode \"name=${repo_name}\" \
    --data-urlencode \"serviceType=web_service\" \
    --data-urlencode \"ownerId=${RENDER_WORKSPACE_ID}\")"

  service_id="$(echo "$service_list" | node -e "const fs=require('fs'); const d=JSON.parse(fs.readFileSync(0,'utf8')); const list=Array.isArray(d) ? d : (d.data || []); const svc=list[0] && list[0].service; if(!svc){process.exit(1)}; console.log(svc.id);")" || true

  if [[ -n "$service_id" ]]; then
    echo "Suspending Render service ${service_id}..."
    curl -sS -X POST \"https://api.render.com/v1/services/${service_id}/suspend\" \
      -H \"Authorization: Bearer ${RENDER_API_KEY}\" >/dev/null

    if [[ "$suspend_only" -eq 0 ]]; then
      echo "Deleting Render service ${service_id}..."
      curl -sS -X DELETE \"https://api.render.com/v1/services/${service_id}\" \
        -H \"Authorization: Bearer ${RENDER_API_KEY}\" >/dev/null
    fi
  else
    echo "No Render service found for ${repo_name}."
  fi
fi

if [[ "$skip_db" -eq 0 ]]; then
  echo "Dropping schema ${schema_name}..."
  psql "$SHARED_DATABASE_URL_ADMIN" -v ON_ERROR_STOP=1 -c "DROP SCHEMA IF EXISTS \"${schema_name}\" CASCADE;" >/dev/null
  echo "Dropping role ${db_user}..."
  psql "$SHARED_DATABASE_URL_ADMIN" -v ON_ERROR_STOP=1 -c "DROP ROLE IF EXISTS \"${db_user}\";" >/dev/null
fi

if [[ "$skip_repo" -eq 0 ]]; then
  echo "Archiving repo ${repo_full}..."
  gh api -X PATCH "repos/${repo_full}" -f archived=true >/dev/null
fi

echo "Cleanup complete."
