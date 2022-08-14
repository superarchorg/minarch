FROM archlinux/archlinux:base-devel as arch
LABEL maintainer="<docker@superarch.org>"

RUN sudo pacman-key --init

RUN pacman -Syu --needed --noconfirm git

# create AUR user
ARG user=aur
RUN useradd --create-home $user \
  && echo "$user ALL=(ALL:ALL) NOPASSWD:ALL" > /etc/sudoers.d/$user
USER $user
WORKDIR /home/$user

# install yay
RUN git clone https://aur.archlinux.org/yay.git \
  && cd yay \
  && makepkg -si --needed --noconfirm \
  && cd

# build pacman-static
RUN yay -Sy --noconfirm pacman-static

# build gpg
RUN git clone https://github.com/skeeto/lean-static-gpg gnupg
RUN cd gnupg && ./build.sh

USER root

FROM debian:unstable-slim as debian

RUN apt-get update && apt-get install -y bash-static

FROM scratch

# copy over everything pacman needs
COPY --from=arch /usr/bin/pacman-static /usr/bin/pacman
COPY --from=arch /etc/pacman.conf /etc/pacman.conf
COPY --from=arch /etc/pacman.d /etc/pacman.d
COPY --from=arch /var/lib/pacman/sync /var/lib/pacman/sync
COPY --from=arch /home/aur/gnupg/gnupg/bin/gpg /usr/bin/gpg
COPY --from=arch /etc/ca-certificates/extracted/tls-ca-bundle.pem \
  /etc/ssl/certs/ca-certificates.crt

# copy over bash-static from debian
COPY --from=debian /bin/bash-static /usr/bin/bash

# set shell path
SHELL ["/usr/bin/bash", "-c"]
