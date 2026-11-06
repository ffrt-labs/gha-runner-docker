#!/bin/bash
set -e

# The host bind-mounts /actions-runner/_work owned by a fixed host uid. If the
# image's runner user doesn't land on that same uid (e.g. a base image change
# shifts useradd's default, as ubuntu:24.04's built-in "ubuntu" user did),
# every job's "Set up job" step fails writing to _work with a permission
# error that looks unrelated to the image at first glance. Fail loudly here
# instead of letting that surface job-by-job on GitHub's side.
work_owner_uid=$(stat -c '%u' /actions-runner/_work)
if [ "$(id -u)" != "$work_owner_uid" ]; then
	echo "❌ Runner is running as uid $(id -u) but /actions-runner/_work is owned by uid $work_owner_uid"
	echo "   Fix the image's useradd/usermod to pin the runner user to uid $work_owner_uid."
	exit 1
fi

if [ -z "$GITHUB_TOKEN" ]; then
	echo "❌ GITHUB_TOKEN is not set in your .env file"
	exit 1
fi
# Register to an org (GITHUB_ORG) or to a single repo (GITHUB_REPO=owner/repo),
# never both: a runner belongs to exactly one of them.
if [ -n "$GITHUB_ORG" ] && [ -n "$GITHUB_REPO" ]; then
	echo "❌ Both GITHUB_ORG and GITHUB_REPO are set in your .env file, set only one"
	exit 1
fi
if [ -n "$GITHUB_REPO" ]; then
	RUNNER_URL="https://github.com/$GITHUB_REPO"
	TOKEN_URL="https://api.github.com/repos/${GITHUB_REPO}/actions/runners/registration-token"
elif [ -n "$GITHUB_ORG" ]; then
	RUNNER_URL="https://github.com/$GITHUB_ORG"
	TOKEN_URL="https://api.github.com/orgs/${GITHUB_ORG}/actions/runners/registration-token"
else
	echo "❌ Neither GITHUB_ORG nor GITHUB_REPO is set in your .env file"
	exit 1
fi

RUNNER_NAME="${RUNNER_NAME:-docker-runner}"
RUNNER_LABELS="${RUNNER_LABELS:-self-hosted,linux,x64}"

if [ -f ./.runner ]; then
	echo "✅ Runner already registered (.runner found), skipping config.sh"
else
	REG_TOKEN=$(curl -s -X POST \
		-H "Authorization: Bearer $GITHUB_TOKEN" \
		-H "Accept: application/vnd.github+json" \
		"$TOKEN_URL" \
		| jq -r '.token')

	if [ -z "$REG_TOKEN" ] || [ "$REG_TOKEN" == "null" ]; then
	     echo "❌ Could not get token. Check your GITHUB_TOKEN and GITHUB_ORG/GITHUB_REPO."
	exit 1
	fi

	./config.sh \
		--url "$RUNNER_URL" \
		--token "$REG_TOKEN" \
		--name "$RUNNER_NAME" \
		--labels "$RUNNER_LABELS" \
		--unattended \
		--replace
	echo "✅ Runner registered"
fi

# Auto-deregister when you stop the container (Ctrl+C)
cleanup() {
	if [ -z "$REG_TOKEN" ]; then
		REG_TOKEN=$(curl -s -X POST \
			-H "Authorization: Bearer $GITHUB_TOKEN" \
			-H "Accept: application/vnd.github+json" \
			"$TOKEN_URL" \
			| jq -r '.token')
	fi
	if [ -z "$REG_TOKEN" ] || [ "$REG_TOKEN" == "null" ]; then
		echo "❌ Could not get token to deregister runner"
		return
	fi
	./config.sh remove --token "$REG_TOKEN"
}
trap cleanup EXIT SIGTERM SIGINT

echo "🚀 Runner is ONLINE — waiting for GitHub jobs..."
./run.sh
