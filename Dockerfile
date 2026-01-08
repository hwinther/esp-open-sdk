FROM debian:bullseye AS build

LABEL maintainer="Hans Christian Winther-Sørensen <hwinther@gmail.com>"

# Install dependencies.
ENV DEBIAN_FRONTEND=noninteractive
RUN apt update && \
    apt install -y git make unrar-free autoconf automake libtool gcc g++ gperf flex bison texinfo gawk ncurses-dev libexpat-dev python-dev python sed git unzip bash help2man wget bzip2 libtool-bin && \
    apt clean && rm -rf /var/lib/apt/lists/*

# The crosstool-NG forbids buildinf as root, so add non-root user to build it.
# Add newly created user right away to 'dialout' group to allow access to serial ports when using esptool.
RUN useradd --create-home --shell /bin/bash --groups dialout sdk

# copy outside repo contents into the image
COPY sdk /home/sdk/esp-open-sdk
RUN chown --recursive sdk /home/sdk/esp-open-sdk

USER sdk
WORKDIR /home/sdk

# Download expat 2.4.8 tarball into crosstool-NG tarballs directory, because the original link is broken.
RUN mkdir -p /home/sdk/esp-open-sdk/crosstool-NG/.build/tarballs && wget -O /home/sdk/esp-open-sdk/crosstool-NG/.build/tarballs/expat-2.4.8.tar.gz https://master.dl.sourceforge.net/project/expat/expat/2.4.8/expat-2.4.8-RENAMED-VULNERABLE-PLEASE-USE-2.6.2-INSTEAD.tar.gz

# Build the SDK.
ARG MAKE_ARGS=""
RUN (cd esp-open-sdk && make ${MAKE_ARGS})

# remove stuff which is not needed anymore to make the image a bit smaller
RUN (cd esp-open-sdk && rm -rf crosstool-NG && rm -rf esp-open-lwip && rm -rf lx106-hal && rm -rf esptool)

FROM debian:bullseye-slim AS final
COPY --from=build /home/sdk/esp-open-sdk /home/sdk/esp-open-sdk

# Add toolchain to PATH
ENV PATH="${PATH}:/home/sdk/esp-open-sdk/xtensa-lx106-elf/bin"
USER root

# switch to python3 because python-serial package is not available in debian bullseye, so we have to use python3-serial
# and esptool will be run with python3 then
RUN apt update && \
    apt install -y python3 python-is-python3 python3-serial make && \
    apt clean && rm -rf /var/lib/apt/lists/*

# make python3 the default, for some reason, installing python-is-python3 package does not work when building on github actions CI
RUN rm /usr/bin/python
RUN ln -s /usr/bin/python3 /usr/bin/python

CMD ["xtensa-lx106-elf-gcc", "--version"]