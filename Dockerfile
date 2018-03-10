# Minimal docker container to build project
# Image: rabits/qt:5.9-android

FROM ubuntu:16.04
MAINTAINER Rabit <home@rabits.org> (@rabits)
ARG QT_VERSION=5.9.4
ARG CRYSTAX_NDK_VERSION=10.3.2
ARG SDK_PLATFORM=android-18
ARG SDK_BUILD_TOOLS=27.0.0
ARG SDK_PACKAGES="tools platform-tools"

ENV DEBIAN_FRONTEND noninteractive
ENV QT_PATH /opt/Qt
ENV QT_ANDROID ${QT_PATH}/${QT_VERSION}/android_armv7
ENV ANDROID_HOME /opt/android-sdk
ENV ANDROID_SDK_ROOT ${ANDROID_HOME}
ENV ANDROID_NDK_ROOT /opt/android-ndk
ENV ANDROID_NDK_TOOLCHAIN_PREFIX arm-linux-androideabi
ENV ANDROID_NDK_TOOLCHAIN_VERSION 4.9
ENV ANDROID_NDK_HOST linux-x86_64
ENV ANDROID_NDK_PLATFORM ${SDK_PLATFORM}
ENV ANDROID_NDK_TOOLS_PREFIX ${ANDROID_NDK_TOOLCHAIN_PREFIX}
ENV QMAKESPEC android-g++
ENV PATH ${QT_ANDROID}/bin:${ANDROID_HOME}/tools:${ANDROID_HOME}/tools/bin:${ANDROID_HOME}/platform-tools:${PATH}

# Install updates & requirements:
#  * git, openssh-client, ca-certificates - clone & build
#  * locales, sudo - useful to set utf-8 locale & sudo usage
#  * curl - to download Qt bundle
#  * make, default-jdk, ant - basic build requirements
#  * libsm6, libice6, libxext6, libxrender1, libfontconfig1, libdbus-1-3 - dependencies of Qt bundle run-file
#  * libc6:i386, libncurses5:i386, libstdc++6:i386, libz1:i386 - dependencides of android sdk binaries
RUN dpkg --add-architecture i386 && apt-get -qq update && apt-get -qq dist-upgrade && apt-get install -qq -y --no-install-recommends \
    git \
    openssh-client \
    ca-certificates \
    locales \
    sudo \
    curl \
    make \
    default-jdk \
    ant \
    bsdtar \
    libsm6 \
    libice6 \
    libxext6 \
    libxrender1 \
    libfontconfig1 \
    libdbus-1-3 \
    xz-utils \
    libc6:i386 \
    libncurses5:i386 \
    libstdc++6:i386 \
    libz1:i386 \
    && apt-get -qq clean

RUN apt-get install -qq -y --no-install-recommends \
    bzip2 \
    unzip \
    gcc \
    g++ \
    cmake \
    patch \
    python3 \
    rsync \
    flex \
    bison

COPY extract-qt-installer.sh /tmp/qt/

# Download & unpack Qt toolchains & clean
RUN curl -Lo /tmp/qt/installer.run "https://download.qt-project.org/official_releases/qt/$(echo ${QT_VERSION} | cut -d. -f 1-2)/${QT_VERSION}/qt-opensource-linux-x64-${QT_VERSION}.run" \
    && QT_CI_PACKAGES=qt.$(echo "${QT_VERSION}" | sed 's/\.//g').android_armv7,qt.$(echo "${QT_VERSION}" | sed 's/\.//g').qtscript.android_armv7,qt.$(echo "${QT_VERSION}" | sed 's/\.//g').android_x86,qt.$(echo "${QT_VERSION}" | sed 's/\.//g').qtscript.x86 /tmp/qt/extract-qt-installer.sh /tmp/qt/installer.run "${QT_PATH}" \
    && find "${QT_PATH}" -mindepth 1 -maxdepth 1 ! -name "${QT_VERSION}" -exec echo 'Cleaning Qt SDK: {}' \; -exec rm -r '{}' \; \
    && rm -rf /tmp/qt

# Download & unpack android SDK
RUN curl -Lo /tmp/sdk-tools.zip 'https://dl.google.com/android/repository/sdk-tools-linux-3859397.zip' \
    && mkdir -p ${ANDROID_HOME} \
    && unzip /tmp/sdk-tools.zip -d ${ANDROID_HOME} \
    && rm -f /tmp/sdk-tools.zip \
    && yes | sdkmanager --licenses && sdkmanager --verbose "platforms;${SDK_PLATFORM}" "build-tools;${SDK_BUILD_TOOLS}" ${SDK_PACKAGES}

# Download & unpack android NDK & remove any platform which is not 
RUN mkdir /tmp/android \
    && cd /tmp/android \
    && curl -Lo ndk.xz "https://www.crystax.net/download/crystax-ndk-${CRYSTAX_NDK_VERSION}-linux-x86_64.tar.xz" \
    && bsdtar -xf /tmp/android/ndk.xz -C /tmp \
    && mv /tmp/crystax-ndk-${CRYSTAX_NDK_VERSION} ${ANDROID_NDK_ROOT} \
    && cd / \
    && rm -rf /tmp/android \
    && find ${ANDROID_NDK_ROOT}/platforms/* -maxdepth 0 ! -name "$ANDROID_NDK_PLATFORM" -type d -exec rm -r {} +

# Reconfigure locale
RUN locale-gen en_US.UTF-8 && dpkg-reconfigure locales
