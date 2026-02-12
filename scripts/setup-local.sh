#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$REPO_ROOT"

if [ ! -f ".env" ]; then
  cp .env.example .env
  echo "Created .env from .env.example"
fi

docker compose up -d
npm install
npx prisma generate
npx prisma migrate dev
