FROM ubuntu:22.04
ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install -y curl tar ca-certificates tini jq e2fsprogs

# git: pinned to the version available in the ubuntu:22.04 (jammy) archive
RUN apt-get install -y git=1:2.34.1-1ubuntu1.17

# gh: pinned to a specific upstream release, installed from the official .deb
RUN curl -o gh.deb -L https://github.com/cli/cli/releases/download/v2.98.0/gh_2.98.0_linux_amd64.deb \
	&& apt-get install -y ./gh.deb \
	&& rm gh.deb

# sbx (Docker Sandboxes): pinned to a specific upstream release, installed from the static tarball
RUN curl -o sbx.tar.gz -L https://github.com/docker/sbx-releases/releases/download/v0.39.0/DockerSandboxes-linux-amd64.tar.gz \
	&& tar xzf sbx.tar.gz \
	&& PREFIX=/usr/local ./docker-sbx/install.sh \
	&& rm -rf sbx.tar.gz docker-sbx

RUN useradd -m runner

WORKDIR /actions-runner

# Linux Runner image. Change for a different OS (mac or windows)
RUN curl -o actions-runner.tar.gz -L https://github.com/actions/runner/releases/download/v2.335.1/actions-runner-linux-x64-2.335.1.tar.gz

RUN tar xzf actions-runner.tar.gz

RUN ./bin/installdependencies.sh

RUN chown -R runner:runner /actions-runner

USER runner

COPY --chown=runner:runner entrypoint.sh .
ENTRYPOINT ["./entrypoint.sh"]
