FROM golang:stretch AS hapttic

RUN git clone https://github.com/jsoendermann/hapttic.git && \
    cd hapttic/ && \
    go build -o hapttic .

FROM debian:stretch-slim AS docker-tc

COPY --from=hapttic /go/hapttic/hapttic /usr/bin/hapttic
RUN hapttic -version && \
    apt-get update && \
    apt-get install -y \
        iproute2 iptables iperf iputils-ping \
        curl jq \
        && \
    rm -rf /var/lib/apt/lists/* && \
    apt-get clean && \
    mkdir -p /var/docker-tc && \
    chmod +x /usr/bin/hapttic

ARG S6_OVERLAY_VERSION=1.21.4.0
RUN curl -sSfL https://github.com/just-containers/s6-overlay/releases/download/v${S6_OVERLAY_VERSION}/s6-overlay-amd64.tar.gz | tar zxvC / && \
    rm -rf /etc/services.d /etc/cont-init.d /etc/cont-finish.d && \
    ln -sf /docker-tc/etc/services.d /etc && \
    ln -sf /docker-tc/etc/cont-init.d /etc && \
    ln -sf /docker-tc/etc/cont-finish.d /etc

ARG DOCKER_VERSION=""
RUN ( curl -fsSL get.docker.com | VERSION=${DOCKER_VERSION} CHANNEL=edge sh ) && \
    rm -rf /var/lib/apt/lists/* && \
    apt-get clean

ENTRYPOINT ["/init"]
EXPOSE 80/tcp
VOLUME ["/var/docker-tc"]
ARG VERSION=dev
ARG VCS_REF
ARG BUILD_DATE
ENV DOCKER_TC_VERSION="${VERSION:-dev}" \
    HTTP_BIND=127.0.0.1 \
    HTTP_PORT=4080 \
    S6_KILL_GRACETIME=0 \
    S6_KILL_FINISH_MAXTIME=0 \
    S6_KEEP_ENV=1 \
    S6_BEHAVIOUR_IF_STAGE2_FAILS=2
LABEL maintainer="Łukasz Lach <llach@llach.pl>" \
      org.opencontainers.image.title="docker-tc" \
      org.opencontainers.image.description="Docker Traffic Control" \
      org.opencontainers.image.authors="Łukasz Lach <llach@llach.pl>" \
      org.opencontainers.image.documentation="https://github.com/lukaszlach/docker-tc" \
      org.opencontainers.image.version=${VERSION} \
      org.opencontainers.image.revision=${VCS_REF} \
      org.opencontainers.image.created=${BUILD_DATE} \
      com.docker-tc.enabled=0 \
      com.docker-tc.self=1

ADD . /docker-tc