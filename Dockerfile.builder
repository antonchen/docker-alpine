# syntax=docker/dockerfile:1

FROM antonhub/alpine:builder as rootfs-stage

# environment
ENV REL=v3.17
ENV ARCH=x86_64
ENV MIRROR=http://dl-cdn.alpinelinux.org/alpine
ENV PACKAGES=alpine-baselayout,alpine-keys,apk-tools,busybox,libc-utils,xz,alpine-release,bash,ca-certificates,coreutils,curl,jq,unzip,netcat-openbsd,procps,shadow,tzdata,build-base

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

# Runtime stage
FROM scratch
COPY --from=rootfs-stage /root-out/ /
LABEL MAINTAINER="Anton Chen <contact@antonchen.com>"

# environment variables
ENV PS1="$(whoami)@$(hostname):$(pwd)\\$ " \
HOME="/root" \
TERM="xterm"
