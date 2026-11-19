#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT_DIR"

find backup minio scripts tests monitoring/backup-exporter -type f \( -name '*.sh' -o -name '*.py' \) -print0 \
  | while IFS= read -r -d '' file; do
      case "$file" in
        *.sh) bash -n "$file" ;;
        *.py) python3 -m py_compile "$file" ;;
      esac
    done
python3 - <<'PY'
import json
json.load(open('monitoring/grafana/dashboards/minvault-overview.json'))
PY
printf 'Contrôles locaux réussis.\n'
