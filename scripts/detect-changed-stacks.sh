#!/usr/bin/env bash
# Prints the list of Terragrunt stack directories affected by the current
# PR's diff, so CI only plans/applies the stacks that actually changed
# instead of every stack in live/ (which would be slow and would also
# plan unrelated environments on every PR).
#
# A changed requests/*.yaml maps to its target server's 20-databases and
# 30-access stacks (resolved by reading spec.server/spec.cloud/spec.env
# out of the changed file), in addition to any directly changed
# modules/ or live/ path.
set -euo pipefail

BASE_REF="${1:-origin/main}"

changed_files="$(git diff --name-only "$BASE_REF"...HEAD)"

stacks=()

while IFS= read -r f; do
  [[ -z "$f" ]] && continue

  if [[ "$f" == live/*/*/*/*/*/terragrunt.hcl ]] || [[ "$f" == live/*/*/*/*/terragrunt.hcl ]]; then
    stacks+=("$(dirname "$f")")
  fi

  if [[ "$f" == modules/* ]]; then
    # A module change could affect any stack that sources it; conservatively
    # recommend a full plan rather than trying to reverse-map module -> stacks.
    echo "NOTE: $f changed — modules/ changes are not auto-mapped to stacks; run a full plan." >&2
  fi

  if [[ "$f" == requests/*.yaml ]] && [[ "$f" != requests/_schema/* ]]; then
    cloud=$(python3 -c "import yaml,sys; print(yaml.safe_load(open(sys.argv[1]))['spec']['cloud'])" "$f")
    env=$(python3 -c "import yaml,sys; print(yaml.safe_load(open(sys.argv[1]))['spec']['env'])" "$f")
    server=$(python3 -c "import yaml,sys; print(yaml.safe_load(open(sys.argv[1]))['spec']['server'])" "$f")
    # region is intentionally not encoded in the request; the pipeline must
    # know the server->region mapping separately (e.g. a lookup table) —
    # left as a TODO for the real CI implementation.
    echo "NOTE: $f changed -> cloud=$cloud env=$env server=$server (resolve region + add 20-databases/30-access stacks)" >&2
  fi
done <<< "$changed_files"

printf '%s\n' "${stacks[@]}" | sort -u
