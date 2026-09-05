# Окружение сборки prplWrt для TP-Link Archer AX50 v1.
#
# Зачем контейнер: база prplWrt — это OpenWrt 19.07, и её проверка хостовых
# зависимостей требует Python 2.x и не распознаёт GCC новее 9-го
# (регулярка в include/prereq-build.mk знает только 4.8–9.x, из-за чего
# на Ubuntu 22.04/24.04 сборка падает ещё до начала). Ubuntu 20.04 даёт
# ровно то, что нужно: GCC 9 и python2 в репозиториях.
FROM ubuntu:20.04

ARG DEBIAN_FRONTEND=noninteractive
ARG UID=1000
ARG GID=1000

RUN apt-get update && apt-get install -y --no-install-recommends \
	bash bison build-essential bzip2 ca-certificates ccache clang \
	device-tree-compiler file flex g++ g++-multilib gawk gcc-multilib \
	gettext git libelf-dev libncurses-dev libssl-dev locales make \
	patch perl python2 python3 python3-distutils python3-setuptools \
	python3-yaml quilt rsync subversion swig time unzip wget \
	xsltproc zlib1g-dev \
	&& rm -rf /var/lib/apt/lists/*

# OpenWrt 19.07 ищет интерпретатор как python/python2
RUN ln -sf /usr/bin/python2 /usr/bin/python

RUN locale-gen en_US.UTF-8
ENV LANG=en_US.UTF-8 LC_ALL=en_US.UTF-8

# сборка не от root — требование OpenWrt
RUN groupadd -g "$GID" builder 2>/dev/null || true; \
    useradd -m -u "$UID" -g "$GID" -s /bin/bash builder 2>/dev/null || true

USER builder
WORKDIR /work
