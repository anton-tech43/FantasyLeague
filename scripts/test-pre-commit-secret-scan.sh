#!/usr/bin/env bash
# Runs scripts/pre-commit-secret-scan.sh against dummy values in a throwaway
# repo: every secret shape must block, every look-alike must pass.
# The dummies are assembled at run time so this file never matches the hook.
set -euo pipefail

hook="$(cd "$(dirname "$0")" && pwd)/pre-commit-secret-scan.sh"
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
cd "$tmp"
git init -q .

hex16=0123456789abcdef
hex80="$hex16$hex16$hex16$hex16$hex16"
hex32="$hex16$hex16"
fail=0

# expect <block|pass> <label> <path> <content>
expect() {
  local want=$1 label=$2 path=$3 content=$4
  git rm -q -r --cached . >/dev/null 2>&1 || true
  rm -rf ./*
  mkdir -p "$(dirname "$path")"
  printf '%s\n' "$content" > "$path"
  git add -- "$path"
  local got=pass
  bash "$hook" >/dev/null 2>&1 || got=block
  if [[ $got == "$want" ]]; then echo "ok    $want  $label"; else echo "FAIL  wanted $want, got $got: $label"; fail=1; fi
}

expect block "JWT"                         a.ts              "const k = \"eyJ""hbGciOiJIUzI1NiIsInR5cCI6\""
expect block "sb_secret"                   a.ts              "k=sb_""secret_abcdefgh12345678"
expect block "Anthropic key"               a.py              "KEY='sk-""ant-api03-abcdefghijklmnopqrstuv'"
expect block "PEM private key"             AuthKey.p8.txt    "-----BEGIN ""PRIVATE KEY-----"
expect block "DB URL with password"        notes.md          "postgresql:""//postgres.abc:hunter2pass@aws-0.pooler.supabase.com:6543/postgres"
expect block "Blotato key"                 config.toml       "Authorization = \"blt_""abcdefghijklmnopqrstuvwx\""
expect block "cron key (80 hex)"           run.sh            "curl -H \"Authorization: Bearer $hex80\""
expect block "API-Football key"            fetch.sh          "-H 'x-apisports-key: $hex32'"
expect block "JWT in a path with a space"  "docs/my notes.md" "eyJ""hbGciOiJIUzI1NiIsInR5cCI6"
alnum50=abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWX
expect block "Meta access token"           .env.example      "META_ACCESS_TOKEN=EA""A$alnum50$alnum50"
expect block "ElevenLabs key"              tts.sh            "ELEVENLABS_API_KEY=sk""_$hex32$hex16"
expect block "OpenAI key"                  a.py              "key = 'sk-""proj-$alnum50'"
expect block "GitHub token"                ci.yml            "token: gh""p_${alnum50:0:36}"
expect pass  "EAA inside base64 image data" i.html           "src=\"data:image/png;base64,iVBORw0KGgoAAAANSUhEU$alnum50""EA""A$alnum50$alnum50\""
expect pass  "publishable key"             a.swift           "let k = \"sb_publishable_abcdefgh12345678\""
expect pass  "photo MD5 (32 hex)"          Pack.swift        "\"$hex32\", // silhouette"
expect pass  "APNs token (64 hex)"         t.sql             "'$hex32$hex32'"
expect pass  "DB URL placeholder"          README.md         "postgresql://postgres:[YOUR-PASSWORD]@db.example.co:5432/postgres"
expect pass  "DB URL env placeholder"      README.md         "postgres://user:\$PGPASSWORD@localhost/db"
expect pass  "80 hex inside an asset"      "A.xcassets/i.imageset/Contents.json" "\"$hex80\""

exit $fail
