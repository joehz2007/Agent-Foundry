#!/usr/bin/env bash
#
# Sync OSL BizPay OpenAPI spec from the public dashboard page.
#
# The page https://dashboard.bizpay.osl.com/openapi does not expose a plain
# openapi.json directly. The OpenAPI object is bundled into an ESM asset like:
#   /assets/openapi-3.0-<hash>.js
# This script finds the current hashed asset, downloads it, imports the exported
# OpenAPI object with Node.js, and writes a standard JSON snapshot.
#
# Output:
#   docs/openapi/osl/openapi.mjs   raw bundled ESM asset
#   docs/openapi/osl/openapi.json  standard OpenAPI JSON spec

set -euo pipefail

BASE_URL="https://dashboard.bizpay.osl.com"
PAGE_URL="$BASE_URL/openapi"
OUT_DIR="docs/openapi/osl"
TMP_DIR="$(mktemp -d)"

cleanup() {
  rm -rf "$TMP_DIR"
}
trap cleanup EXIT

mkdir -p "$OUT_DIR"

echo "Fetching OpenAPI page: $PAGE_URL" >&2
curl -fsSL \
  -H 'User-Agent: Mozilla/5.0' \
  "$PAGE_URL" \
  -o "$TMP_DIR/page.html"

INDEX_JS="$(python3 - "$TMP_DIR/page.html" "$BASE_URL" <<'PY'
import re
import sys
from urllib.parse import urljoin

page_path, base_url = sys.argv[1], sys.argv[2]
html = open(page_path, encoding='utf-8').read()
# Prefer the main Vite/React index bundle.
matches = re.findall(r'<script[^>]+src="([^"]*assets/index-[^"]+\.js)"', html)
if not matches:
    matches = re.findall(r'src="([^"]+\.js)"', html)
if not matches:
    raise SystemExit('Cannot find index JavaScript asset from page')
print(urljoin(base_url + '/', matches[0]))
PY
)"

echo "Fetching index bundle: $INDEX_JS" >&2
curl -fsSL \
  -H 'User-Agent: Mozilla/5.0' \
  "$INDEX_JS" \
  -o "$TMP_DIR/index.js"

OPENAPI_JS="$(python3 - "$TMP_DIR/index.js" "$BASE_URL" <<'PY'
import re
import sys
from urllib.parse import urljoin

index_path, base_url = sys.argv[1], sys.argv[2]
js = open(index_path, encoding='utf-8', errors='replace').read()
matches = re.findall(r'assets/openapi-3\.0-[A-Za-z0-9_-]+\.js', js)
if not matches:
    raise SystemExit('Cannot find OpenAPI asset from index bundle')
print(urljoin(base_url + '/', matches[0]))
PY
)"

echo "Fetching OpenAPI bundle: $OPENAPI_JS" >&2
curl -fsSL \
  -H 'User-Agent: Mozilla/5.0' \
  "$OPENAPI_JS" \
  -o "$OUT_DIR/openapi.mjs"

SPEC_MODULE="$PWD/$OUT_DIR/openapi.mjs" \
node --input-type=module <<'NODE' > "$OUT_DIR/openapi.json.tmp"
import { pathToFileURL } from 'url';

const moduleUrl = pathToFileURL(process.env.SPEC_MODULE).href;
const mod = await import(moduleUrl);
const spec = mod.o || mod.default || mod.openapi;

if (!spec || !spec.openapi || !spec.info || !spec.paths) {
  throw new Error('The exported object is not a valid-looking OpenAPI spec');
}

console.log(JSON.stringify(spec, null, 2));
NODE

python3 - "$OUT_DIR/openapi.json.tmp" <<'PY'
import json
import sys

path = sys.argv[1]
with open(path, encoding='utf-8') as f:
    spec = json.load(f)
if not str(spec.get('openapi', '')).startswith('3.'):
    raise SystemExit('Unsupported or missing openapi version')
if not isinstance(spec.get('paths'), dict) or not spec['paths']:
    raise SystemExit('OpenAPI paths is empty')
print(f"Validated OpenAPI {spec.get('openapi')} with {len(spec['paths'])} paths", file=sys.stderr)
PY

mv "$OUT_DIR/openapi.json.tmp" "$OUT_DIR/openapi.json"

cat >&2 <<EOF
Saved:
  $OUT_DIR/openapi.mjs
  $OUT_DIR/openapi.json
EOF
