#!/bin/bash

set -euo pipefail

ROOT=$(realpath "${BASH_SOURCE[0]%/*}/..")

for script in "$ROOT"/bin/* "$ROOT"/build/*.sh "$ROOT"/helpers/*.sh "$ROOT"/test/*.sh; do
  [[ -f $script ]] || continue
  bash -n "$script"
done

"$ROOT/test/repo-identity-test.sh"
"$ROOT/test/package-wave-test.sh"
"$ROOT/test/database-signing-test.sh"
"$ROOT/bin/repo" build --dry-run

echo "All tests passed"
