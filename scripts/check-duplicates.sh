#!/usr/bin/env bash
# Fails CI if the same (server, database) pair or the same principal
# name/object_id appears in more than one requests/*.yaml file.
# Rationale: live/.../20-databases merges all matching request files
# with `merge()`, which silently lets a later duplicate key win —
# see section 9.3 of the platform design. This check is what actually
# prevents that silent override, not the Terraform code itself.
set -euo pipefail

cd "$(git rev-parse --show-toplevel)"

python3 - <<'PY'
import sys, glob, yaml
from collections import defaultdict

seen_db = defaultdict(list)       # (server, db_name) -> [request_file,...]
seen_principal = defaultdict(list)  # principal_name -> [request_file,...]

files = [f for f in glob.glob("requests/**/*.yaml", recursive=True)
         if not f.startswith("requests/_schema/")]

for f in files:
    with open(f, encoding="utf-8") as fh:
        doc = yaml.safe_load(fh)
    if not doc or doc.get("kind") != "DatabaseRequest":
        continue
    spec = doc["spec"]
    server = spec["server"]
    for db in spec["databases"]:
        seen_db[(server, db["name"])].append(f)

    access = spec["access"]
    principals = [a["principal"] for a in access.get("apps", [])]
    principals.append(access["migration"]["principal"])
    principals += [e["group"] for e in access.get("engineers", [])]
    for p in principals:
        seen_principal[p].append(f)

errors = []
for key, files_ in seen_db.items():
    if len(files_) > 1:
        errors.append(f"Duplicate (server, database) {key} in: {files_}")
for name, files_ in seen_principal.items():
    unique_files = sorted(set(files_))
    if len(unique_files) > 1:
        errors.append(f"Principal '{name}' referenced in multiple files: {unique_files}")

if errors:
    print("Duplicate request check FAILED:", file=sys.stderr)
    for e in errors:
        print(f"  - {e}", file=sys.stderr)
    sys.exit(1)

print(f"Duplicate request check passed ({len(files)} request files checked).")
PY
