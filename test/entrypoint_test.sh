#!/bin/bash
# Runs entrypoint.sh against stubbed curl/config.sh/run.sh and checks which
# URL and token endpoint it picks for GITHUB_ORG vs GITHUB_REPO.
set -u

ENTRYPOINT="$(cd "$(dirname "$0")/.." && pwd)/entrypoint.sh"
failures=0

# Runs the entrypoint in a scratch dir with the given env; leaves the calls
# it made in $work/calls and its output in $work/out.
run_entrypoint() {
	work=$(mktemp -d)
	mkdir -p "$work/bin"
	# _work ownership check: report whatever uid we're running as
	printf '#!/bin/bash\nid -u\n' >"$work/bin/stat"
	printf '#!/bin/bash\necho "curl ${@: -1}" >>"%s/calls"\necho "{\\"token\\":\\"T\\"}"\n' "$work" >"$work/bin/curl"
	printf '#!/bin/bash\necho "config.sh $*" >>"%s/calls"\n' "$work" >"$work/config.sh"
	printf '#!/bin/bash\ntrue\n' >"$work/run.sh"
	chmod +x "$work/bin/"* "$work/config.sh" "$work/run.sh"
	(cd "$work" && env -i PATH="$work/bin:$PATH" GITHUB_TOKEN=x "$@" bash "$ENTRYPOINT") >"$work/out" 2>&1
	status=$?
	touch "$work/calls"
}

expect() {
	local name="$1" pattern="$2" file="$3"
	if grep -qF -- "$pattern" "$file"; then
		echo "✅ $name"
	else
		echo "❌ $name: expected '$pattern' in:"
		sed 's/^/   /' "$file"
		failures=$((failures + 1))
	fi
}

expect_failed_before_registering() {
	if [ "$status" -ne 0 ] && [ ! -s "$work/calls" ]; then
		echo "✅ $1: exits non-zero without calling GitHub"
	else
		echo "❌ $1: expected non-zero exit and no calls, got status $status and:"
		sed 's/^/   /' "$work/calls"
		failures=$((failures + 1))
	fi
}

run_entrypoint GITHUB_REPO=felipeafreitas/backlog
expect "repo: registration token from repos endpoint" "curl https://api.github.com/repos/felipeafreitas/backlog/actions/runners/registration-token" "$work/calls"
expect "repo: configures against repo URL" "config.sh --url https://github.com/felipeafreitas/backlog " "$work/calls"
expect "repo: deregisters on exit" "config.sh remove --token T" "$work/calls"

run_entrypoint GITHUB_ORG=ffrt-labs
expect "org: registration token from orgs endpoint" "curl https://api.github.com/orgs/ffrt-labs/actions/runners/registration-token" "$work/calls"
expect "org: configures against org URL" "config.sh --url https://github.com/ffrt-labs " "$work/calls"
expect "org: deregisters on exit" "config.sh remove --token T" "$work/calls"

run_entrypoint
expect "neither: fails with a clear message" "Neither GITHUB_ORG nor GITHUB_REPO is set" "$work/out"
expect_failed_before_registering "neither"

run_entrypoint GITHUB_ORG=ffrt-labs GITHUB_REPO=felipeafreitas/backlog
expect "both: fails with a clear message" "Both GITHUB_ORG and GITHUB_REPO are set" "$work/out"
expect_failed_before_registering "both"

exit $((failures > 0))
