FROM ubuntu:22.04
ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install -y curl tar ca-certificates tini jq

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
