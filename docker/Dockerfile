# Окружение сборки prplWrt (база OpenWrt 19.07): нужны Python 2.x и GCC <= 9,
# поэтому Ubuntu 20.04. Используется локально (scripts/docker.sh); CI ставит
# тот же список пакетов (.github/workflows/*.yml, переменная BUILD_DEPS).
FROM ubuntu:20.04

ARG DEBIAN_FRONTEND=noninteractive
ARG UID=1000
ARG GID=1000

RUN apt-get update && apt-get install -y --no-install-recommends \
	bash bison build-essential bzip2 ca-certificates ccache curl \
	device-tree-compiler file flex g++ g++-multilib gawk gcc-multilib \
	gettext git libelf-dev libncurses-dev libssl-dev locales make \
	patch perl python2 python3 python3-distutils python3-setuptools \
	python3-yaml quilt rsync subversion swig time unzip wget xsltproc \
	xz-utils zlib1g-dev zstd \
	&& rm -rf /var/lib/apt/lists/* \
	&& ln -sf /usr/bin/python2 /usr/bin/python \
	&& locale-gen en_US.UTF-8

ENV LANG=en_US.UTF-8 LC_ALL=en_US.UTF-8

# Необязательный корпоративный/прокси CA (локальные сборки за TLS-прокси)
COPY extra-ca.crt* /usr/local/share/ca-certificates/
RUN update-ca-certificates >/dev/null 2>&1 || true

RUN groupadd -g "$GID" builder 2>/dev/null || true; \
	useradd -m -u "$UID" -g "$GID" -s /bin/bash builder

USER builder
WORKDIR /work
