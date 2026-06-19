#!/bin/bash
set -e

if [ -z "$GITHUB_TOKEN" ]; then
	echo "❌ GITHUB_TOKEN is not set in your .env file"
	exit 1
fi
if [ -z "$GITHUB_ORG" ]; then
	echo "❌ GITHUB_ORG is not set in your .env file"
	exit 1
fi

RUNNER_NAME="${RUNNER_NAME:-docker-runner}"
RUNNER_LABELS="${RUNNER_LABELS:-self-hosted,linux,x64}"

RUNNER_URL="https://github.com/$GITHUB_ORG"
REG_TOKEN=$(curl -s -X POST \
	-H "Authorization: Bearer $GITHUB_TOKEN" \
	-H "Accept: application/vnd.github+json" \
	"https://api.github.com/orgs/${GITHUB_ORG}/actions/runners/registration-token" \
	| jq -r '.token')

if [ -z "$REG_TOKEN" ] || [ "$REG_TOKEN" == "null" ]; then
     echo "❌ Could not get token. Check your GITHUB_TOKEN and REPO_URL."
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

# Auto-deregister when you stop the container (Ctrl+C)
cleanup() {
	./config.sh remove --token "$REG_TOKEN"
}
trap cleanup EXIT SIGTERM SIGINT

echo "🚀 Runner is ONLINE — waiting for GitHub jobs..."
./run.sh
