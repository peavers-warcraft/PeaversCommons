#!/bin/bash
# Runs the offline harness. Needs `lua` on PATH. Unlike the other addons' test
# suites this one has no sibling-repo dependency: the modules it covers are the
# ones written to load without a client.
set -euo pipefail

cd "$(dirname "$0")/.."

status=0
for test in tests/test_*.lua; do
	echo "=== $test"
	lua "$test" || status=1
done

exit "$status"
