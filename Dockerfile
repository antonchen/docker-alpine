# syntax=docker/dockerfile:1

FROM antonhub/alpine:builder as rootfs-stage

# environment
ENV REL=v3.17
ENV ARCH=x86_64
ENV MIRROR=http://dl-cdn.alpinelinux.org/alpine
ENV PACKAGES=alpine-baselayout,\
alpine-keys,\
apk-tools,\
busybox,\
libc-utils,\
xz

# fetch builder script from gliderlabs
RUN \
  curl -o \
  /mkimage-alpine.bash -L \
    https://raw.githubusercontent.com/gliderlabs/docker-alpine/master/builder/scripts/mkimage-alpine.bash && \
  chmod +x \
    /mkimage-alpine.bash && \
  ./mkimage-alpine.bash  && \
  mkdir /root-out && \
  tar xf \
    /rootfs.tar.xz -C \
    /root-out && \
  sed -i -e 's/^root::/root:!:/' /root-out/etc/shadow

# set version for s6 overlay
ARG S6_OVERLAY_VERSION="3.1.4.2"
ARG S6_OVERLAY_ARCH="x86_64"

# add s6 overlay
ADD https://github.com/just-containers/s6-overlay/releases/download/v${S6_OVERLAY_VERSION}/s6-overlay-noarch.tar.xz /tmp
RUN tar -C /root-out -Jxpf /tmp/s6-overlay-noarch.tar.xz
ADD https://github.com/just-containers/s6-overlay/releases/download/v${S6_OVERLAY_VERSION}/s6-overlay-${S6_OVERLAY_ARCH}.tar.xz /tmp
RUN tar -C /root-out -Jxpf /tmp/s6-overlay-${S6_OVERLAY_ARCH}.tar.xz

# add s6 optional symlinks
ADD https://github.com/just-containers/s6-overlay/releases/download/v${S6_OVERLAY_VERSION}/s6-overlay-symlinks-noarch.tar.xz /tmp
RUN tar -C /root-out -Jxpf /tmp/s6-overlay-symlinks-noarch.tar.xz
ADD https://github.com/just-containers/s6-overlay/releases/download/v${S6_OVERLAY_VERSION}/s6-overlay-symlinks-arch.tar.xz /tmp
RUN tar -C /root-out -Jxpf /tmp/s6-overlay-symlinks-arch.tar.xz

COPY --chmod=744 docker-mods.v3 /root-out/docker-mods
# add local files
COPY root/ /root-out/
RUN find /root-out/etc/s6-overlay -name run|xargs chmod 755

# Runtime stage
FROM scratch
COPY --from=rootfs-stage /root-out/ /
LABEL MAINTAINER="Anton Chen <contact@antonchen.com>"

# environment variables
ENV PS1="$(whoami)@$(hostname):$(pwd)\\$ " \
HOME="/root" \
TERM="xterm" \
RUNUSER="alpine" \
S6_CMD_WAIT_FOR_SERVICES_MAXTIME="0" \
S6_VERBOSITY=1 \
S6_STAGE2_HOOK=/docker-mods

RUN \
  echo "**** install runtime packages ****" && \
  apk add --no-cache \
    alpine-release \
    bash \
    ca-certificates \
    coreutils \
    curl \
    jq \
    netcat-openbsd \
    procps \
    shadow \
    tzdata && \
  echo "**** create $RUNUSER user and make our folders ****" && \
  groupmod -g 1000 users && \
  useradd -u 5900 -U -d /config -s /bin/false $RUNUSER && \
  usermod -G users $RUNUSER && \
  mkdir -p \
    /app \
    /config \
    /defaults && \
  echo "**** cleanup ****" && \
  rm -rf \
    /tmp/*

ENTRYPOINT ["/init"]
