FROM alpine:3.9 as rootfs-stage
MAINTAINER antonchen

# environment
ENV REL=v3.9
ENV MIRROR=http://dl-cdn.alpinelinux.org/alpine

# install packages
RUN \
 apk add --no-cache \
    bash \
    curl \
    tzdata \
    xz

# fetch builder script from gliderlabs
RUN \
 curl -o \
 /mkimage-alpine.bash -L \
    https://raw.githubusercontent.com/gliderlabs/docker-alpine/master/builder/scripts/mkimage-alpine.bash && \
 chmod +x \
    /mkimage-alpine.bash && \
 ./mkimage-alpine.bash -r ${REL} -m ${MIRROR} -a $(uname -m) && \
 mkdir /root-out && \
 tar xf \
    /rootfs.tar.xz -C \
    /root-out

# Runtime stage
FROM scratch
COPY --from=rootfs-stage /root-out/ /
LABEL MAINTAINER="Anton Chen <contact@antonchen.com>"

# set version for s6 overlay
ARG OVERLAY_VERSION="v1.22.1.0"
ARG OVERLAY_ARCH="amd64"

# environment variables
ENV PS1="$(whoami)@$(hostname):$(pwd)\\$ "
ENV HOME="/root"
ENV TERM="xterm"
ENV TZ=UTC

RUN \
 echo "**** install build packages ****" && \
 apk add --no-cache --virtual=build-dependencies \
    curl \
    tar && \
 echo "**** install runtime packages ****" && \
 apk add --no-cache \
    bash \
    ca-certificates \
    coreutils \
    shadow \
    tzdata && \
 update-ca-certificates && \
 echo "**** add s6 overlay ****" && \
 curl -o \
 /tmp/s6-overlay.tar.gz -L \
    https://github.com/just-containers/s6-overlay/releases/download/${OVERLAY_VERSION}/s6-overlay-${OVERLAY_ARCH}.tar.gz && \
 tar xfz \
    /tmp/s6-overlay.tar.gz -C / && \
 echo "**** create alpine user and make our folders ****" && \
 groupmod -g 1000 users && \
 useradd -u 911 -U -s /bin/false alpine && \
 usermod -G users alpine && \
 echo "**** cleanup ****" && \
 apk del --purge \
    build-dependencies && \
 rm -rf \
    /tmp/*

# add local files
COPY root/ /

ENTRYPOINT ["/init"]
