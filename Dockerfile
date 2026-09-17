# 24.04, not 22.04: sbx v0.39.0's bundled mkfs.erofs binary is linked against
# GLIBC_2.38, which jammy's glibc (2.35) doesn't provide. It fails silently
# from sbx's own perspective — sandboxd just reports its transfer.v1 plugin
# (and everything downstream of it) as unavailable, with no glibc/erofs
# wording anywhere in the visible error chain. Confirmed live: `mkfs.erofs
# --help` inside a jammy-based runner container fails with
# "GLIBC_2.38 not found"; noble ships 2.39.
FROM ubuntu:24.04
ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install -y curl tar ca-certificates tini jq e2fsprogs

# git: pinned to the version available in the ubuntu:24.04 (noble) archive
RUN apt-get install -y git=1:2.43.0-1ubuntu7.3

# gh: pinned to a specific upstream release, installed from the official .deb
RUN curl -o gh.deb -L https://github.com/cli/cli/releases/download/v2.98.0/gh_2.98.0_linux_amd64.deb \
	&& apt-get install -y ./gh.deb \
	&& rm gh.deb

# sbx (Docker Sandboxes): pinned to a specific upstream release, installed from the static tarball
RUN curl -o sbx.tar.gz -L https://github.com/docker/sbx-releases/releases/download/v0.39.0/DockerSandboxes-linux-amd64.tar.gz \
	&& tar xzf sbx.tar.gz \
	&& PREFIX=/usr/local ./docker-sbx/install.sh \
	&& rm -rf sbx.tar.gz docker-sbx

# Node.js: pinned to a specific upstream LTS release, installed from the official static tarball
RUN curl -o node.tar.gz -L https://nodejs.org/dist/v24.21.0/node-v24.21.0-linux-x64.tar.gz \
	&& tar xzf node.tar.gz -C /usr/local --strip-components=1 \
	&& rm node.tar.gz

# ubuntu:24.04 ships a built-in "ubuntu" user/group at uid/gid 1000, unlike
# 22.04 -- left alone, useradd below would land runner on 1001 instead. The
# host's bind-mounted /actions-runner/_work is owned by the host's uid 1000,
# so runner must land on 1000 too, or every job's "Set up job" step fails
# writing to _work with a permission error. Confirmed live.
RUN userdel -r ubuntu
RUN groupadd -g 1000 runner && useradd -m -u 1000 -g 1000 runner

WORKDIR /actions-runner

# Linux Runner image. Change for a different OS (mac or windows)
RUN curl -o actions-runner.tar.gz -L https://github.com/actions/runner/releases/download/v2.335.1/actions-runner-linux-x64-2.335.1.tar.gz

RUN tar xzf actions-runner.tar.gz

RUN ./bin/installdependencies.sh

RUN chown -R runner:runner /actions-runner

USER runner

COPY --chown=runner:runner entrypoint.sh .
ENTRYPOINT ["./entrypoint.sh"]
