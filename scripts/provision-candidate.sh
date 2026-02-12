#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'USAGE'
Usage:
  scripts/provision-candidate.sh <candidate_slug> [options]

Options:
  --github <username>       GitHub username to add as collaborator
  --email <email>           Candidate email (for manual invite note)
  --render-region <region>  Render region (default: oregon)
  --render-plan <plan>      Render plan (default: starter)
  --ttl-days <days>         TTL for candidate (default: 10)
  --clone                   Clone repo locally and stamp .candidate.json
  --show-secrets            Print secrets in output (disabled by default)
  --help                    Show this help

Required env vars:
  GITHUB_ORG
  TEMPLATE_REPO
  RENDER_API_KEY
  RENDER_WORKSPACE_ID
  SHARED_DATABASE_URL_ADMIN
  SHARED_DATABASE_URL_BASE
  DEBUG_KEY (optional; generated if missing)

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

generate_debug_key() {
  if command -v openssl >/dev/null 2>&1; then
    openssl rand -hex 16
    return
  fi
  if command -v uuidgen >/dev/null 2>&1; then
    uuidgen | tr '[:upper:]' '[:lower:]' | tr -d '-'
    return
  fi
  echo "Missing openssl or uuidgen for DEBUG_KEY generation" >&2
  exit 1
}

generate_db_password() {
  generate_debug_key
}

candidate_slug="${1:-}"
if [[ -z "$candidate_slug" ]]; then
  usage
  exit 1
fi
shift || true

candidate_github=""
candidate_email=""
render_region="oregon"
render_plan="starter"
ttl_days="10"
clone_repo=0
show_secrets=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --github)
      candidate_github="$2"
      shift 2
      ;;
    --email)
      candidate_email="$2"
      shift 2
      ;;
    --render-region)
      render_region="$2"
      shift 2
      ;;
    --render-plan)
      render_plan="$2"
      shift 2
      ;;
    --ttl-days)
      ttl_days="$2"
      shift 2
      ;;
    --clone)
      clone_repo=1
      shift
      ;;
    --show-secrets)
      show_secrets=1
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
require_env TEMPLATE_REPO
require_env RENDER_API_KEY
require_env RENDER_WORKSPACE_ID
require_env SHARED_DATABASE_URL_ADMIN
require_env SHARED_DATABASE_URL_BASE

require_cmd gh
require_cmd git
require_cmd curl
require_cmd psql
require_cmd node

repo_name="emoji-battle-${candidate_slug}"
repo_full="${GITHUB_ORG}/${repo_name}"

if gh api "repos/${repo_full}" >/dev/null 2>&1; then
  echo "Repo already exists: ${repo_full}. Choose a new slug or delete the repo." >&2
  exit 1
fi

repo_url="https://github.com/${repo_full}"
schema_base="$(sanitize_slug "$candidate_slug")"
if [[ -z "$schema_base" ]]; then
  echo "Invalid candidate slug: $candidate_slug" >&2
  exit 1
fi
schema_name="eb_${schema_base}"
db_user_prefix="${DB_USER_PREFIX:-eb_user_}"
db_user="${db_user_prefix}${schema_base}"
db_password="$(generate_db_password)"

debug_key="${DEBUG_KEY:-}"
if [[ -z "$debug_key" ]]; then
  debug_key="$(generate_debug_key)"
fi

echo "Creating repo ${repo_full}..."
gh repo create "$repo_full" --private --template "${GITHUB_ORG}/${TEMPLATE_REPO}" --confirm >/dev/null

if [[ -n "$candidate_github" ]]; then
  echo "Adding collaborator ${candidate_github}..."
  gh api -X PUT "repos/${repo_full}/collaborators/${candidate_github}" -f permission=pull >/dev/null
elif [[ -n "$candidate_email" ]]; then
  echo "No GitHub username provided; will remind to invite ${candidate_email} manually."
fi

default_branch="$(gh api "repos/${repo_full}" -q .default_branch)"
commit_sha=""

if [[ "$clone_repo" -eq 1 ]]; then
  echo "Cloning repo for stamping..."
  clone_root="$(mktemp -d)"
  clone_dir="${clone_root}/${repo_name}"
  git clone "git@github.com:${repo_full}.git" "$clone_dir" >/dev/null
  created_at="$(date -u +"%Y-%m-%dT%H:%M:%SZ")"
  expires_at="$(date -u -v "+${ttl_days}d" +"%Y-%m-%dT%H:%M:%SZ")"
  cat > "${clone_dir}/.candidate.json" <<EOF
{
  "slug": "${candidate_slug}",
  "createdAt": "${created_at}",
  "ttlDays": ${ttl_days},
  "expiresAt": "${expires_at}",
  "github": "${candidate_github}",
  "email": "${candidate_email}"
}
EOF
  git -C "$clone_dir" add .candidate.json
  git -C "$clone_dir" commit -m "chore: stamp candidate metadata" >/dev/null
  git -C "$clone_dir" push origin "$default_branch" >/dev/null
  commit_sha="$(git -C "$clone_dir" rev-parse HEAD)"
else
  commit_sha="$(gh api "repos/${repo_full}/commits/${default_branch}" -q .sha)"
fi

echo "Creating schema ${schema_name}..."
psql "$SHARED_DATABASE_URL_ADMIN" -v ON_ERROR_STOP=1 -c "CREATE SCHEMA IF NOT EXISTS \"${schema_name}\";" >/dev/null

echo "Creating database role ${db_user}..."
psql "$SHARED_DATABASE_URL_ADMIN" -v ON_ERROR_STOP=1 -c "DO \$\$ BEGIN IF EXISTS (SELECT 1 FROM pg_roles WHERE rolname = '${db_user}') THEN ALTER ROLE \"${db_user}\" WITH PASSWORD '${db_password}'; ELSE CREATE ROLE \"${db_user}\" WITH LOGIN PASSWORD '${db_password}'; END IF; END \$\$;" >/dev/null
psql "$SHARED_DATABASE_URL_ADMIN" -v ON_ERROR_STOP=1 -c "GRANT USAGE, CREATE ON SCHEMA \"${schema_name}\" TO \"${db_user}\";" >/dev/null
psql "$SHARED_DATABASE_URL_ADMIN" -v ON_ERROR_STOP=1 -c "ALTER DEFAULT PRIVILEGES IN SCHEMA \"${schema_name}\" GRANT SELECT, INSERT, UPDATE, DELETE ON TABLES TO \"${db_user}\";" >/dev/null
psql "$SHARED_DATABASE_URL_ADMIN" -v ON_ERROR_STOP=1 -c "ALTER DEFAULT PRIVILEGES IN SCHEMA \"${schema_name}\" GRANT USAGE, SELECT, UPDATE ON SEQUENCES TO \"${db_user}\";" >/dev/null

echo "Creating Render service..."
create_payload="$(cat <<EOF
{
  \"type\": \"web_service\",
  \"name\": \"${repo_name}\",
  \"ownerId\": \"${RENDER_WORKSPACE_ID}\",
  \"repo\": \"${repo_url}\",
  \"branch\": \"${default_branch}\",
  \"autoDeploy\": \"yes\",
  \"serviceDetails\": {
    \"runtime\": \"node\",
    \"region\": \"${render_region}\",
    \"plan\": \"${render_plan}\",
    \"healthCheckPath\": \"/health\",
    \"preDeployCommand\": \"npx prisma migrate deploy\",
    \"envSpecificDetails\": {
      \"buildCommand\": \"npm ci && npm run build\",
      \"startCommand\": \"npm run start\"
    }
  }
}
EOF
)"

service_response="$(curl -sS -X POST \"https://api.render.com/v1/services\" \
  -H \"Authorization: Bearer ${RENDER_API_KEY}\" \
  -H \"Content-Type: application/json\" \
  -d \"${create_payload}\")"

service_id="$(echo "$service_response" | node -e "const fs=require('fs'); const d=JSON.parse(fs.readFileSync(0,'utf8')); const svc=d.service || (d.data && d.data.service); if(!svc){process.exit(1)}; console.log(svc.id);")"
render_url="$(echo "$service_response" | node -e "const fs=require('fs'); const d=JSON.parse(fs.readFileSync(0,'utf8')); const svc=d.service || (d.data && d.data.service); if(!svc){process.exit(1)}; const url=svc.serviceDetails && svc.serviceDetails.url; if(!url){process.exit(1)}; console.log(url);")" || true

database_url="$(node -e "const base=new URL(process.env.SHARED_DATABASE_URL_BASE); base.username='${db_user}'; base.password='${db_password}'; base.searchParams.set('schema','${schema_name}'); console.log(base.toString());")"
env_payload="$(cat <<EOF
[
  {\"key\":\"DATABASE_URL\",\"value\":\"${database_url}\"},
  {\"key\":\"DEBUG_KEY\",\"value\":\"${debug_key}\"},
  {\"key\":\"GIT_SHA\",\"value\":\"${commit_sha}\"},
  {\"key\":\"NODE_ENV\",\"value\":\"production\"}
]
EOF
)"

echo "Setting Render environment variables..."
curl -sS -X PUT \"https://api.render.com/v1/services/${service_id}/env-vars\" \
  -H \"Authorization: Bearer ${RENDER_API_KEY}\" \
  -H \"Content-Type: application/json\" \
  -d \"${env_payload}\" >/dev/null

echo "Triggering deploy..."
curl -sS -X POST \"https://api.render.com/v1/services/${service_id}/deploys\" \
  -H \"Authorization: Bearer ${RENDER_API_KEY}\" \
  -H \"Content-Type: application/json\" \
  -d \"{\\\"commitId\\\":\\\"${commit_sha}\\\"}\" >/dev/null

if [[ -z "$render_url" ]]; then
  render_url="$(curl -sS \"https://api.render.com/v1/services/${service_id}\" \
    -H \"Authorization: Bearer ${RENDER_API_KEY}\" \
    | node -e \"const fs=require('fs'); const d=JSON.parse(fs.readFileSync(0,'utf8')); const svc=d.service || d.data || d; const url=svc.serviceDetails && svc.serviceDetails.url; if(!url) process.exit(1); console.log(url);\")"
fi

if [[ -n "$render_url" ]]; then
  echo "Waiting for /health on ${render_url} ..."
  attempts=0
  until [[ "$attempts" -ge 30 ]]; do
    attempts=$((attempts + 1))
    health_json="$(curl -sS \"${render_url}/health\" || true)"
    if echo "$health_json" | node -e "const fs=require('fs'); try { const d=JSON.parse(fs.readFileSync(0,'utf8')); const ok=d.ok===true && d.schema==='${schema_name}' && d.db && d.db.ok===true && d.gitSha==='${commit_sha}'; process.exit(ok?0:1);} catch { process.exit(1);}"; then
      break
    fi
    sleep 10
  done
  if [[ "$attempts" -ge 30 ]]; then
    echo "Warning: /health did not validate after polling." >&2
  fi
else
  echo "Warning: Render URL unavailable for health polling." >&2
fi

cat <<EOF

Provisioning complete
---------------------
Repo: ${repo_url}
Render service id: ${service_id}
Render URL: ${render_url}
Schema: ${schema_name}
DB user: ${db_user}
EOF

if [[ "$show_secrets" -eq 1 ]]; then
  cat <<EOF
Secrets:
  DEBUG_KEY: ${debug_key}
  DATABASE_URL: ${database_url}
  DB_PASSWORD: ${db_password}
EOF
fi

cat <<EOF

Candidate handoff block:
Repo: ${repo_url}
Deployed URL: ${render_url}
Notes: You won't have Render access. Use /health to verify deploy. Local dev uses docker-compose.
EOF

if [[ -n "$candidate_email" ]]; then
  echo "Reminder: invite ${candidate_email} manually."
fi
