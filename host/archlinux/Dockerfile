FROM archlinux:latest

RUN pacman-key --init
RUN pacman -Syu --noconfirm \
	&& pacman -S --noconfirm gcc clang flex bison ccache \
		pkg-config ninja automake autoconf libtool \
		wget curl git bc squashfs-tools \
		rsync jq cmake openssh tree parallel \
		python3 python-pip tcl scons dtc cpio \
		fakeroot fakechroot bzr ncurses cvs file \
		mercurial unzip subversion gawk diffstat \
		texinfo chrpath socat ckermit neovim zstd \
		cscope confuse dosfstools mtools gettext e2fsprogs \
		which make patch perl

ENV PATH="/usr/bin/core_perl:${PATH}"
RUN echo en_US.UTF-8 UTF-8 >> /etc/locale.gen
RUN locale-gen

# Create a non-root build user whose UID/GID matches the host user.
# Pass --build-arg UID=$(id -u) --build-arg GID=$(id -g) when building so that
# files in the mounted repo volume are owned by the container user and
# autotools configure does not refuse to run as root.
ARG UID=1000
ARG GID=1000
RUN groupadd -g ${GID} build \
    && useradd -m -u ${UID} -g ${GID} -s /bin/bash build

USER build
WORKDIR /build
