FROM python:3.11-slim AS ffmpeg-builder

# Install build dependencies for FFmpeg
RUN apt-get update && apt-get install -y --no-install-recommends \
    build-essential \
    wget \
    yasm \
    nasm \
    pkg-config \
    ca-certificates \
    autoconf \
    automake \
    libtool \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /build

# Build libfdk-aac (static)
RUN wget -q https://github.com/mstorsjo/fdk-aac/archive/refs/tags/v2.0.3.tar.gz && \
    tar xf v2.0.3.tar.gz && \
    cd fdk-aac-2.0.3 && \
    autoreconf -fiv && \
    ./configure --prefix=/usr/local --enable-static --disable-shared && \
    make -j4 && \
    make install && \
    cd .. && rm -rf fdk-aac-2.0.3 v2.0.3.tar.gz

# Build libmp3lame (static)
RUN wget -q https://sourceforge.net/projects/lame/files/lame/3.100/lame-3.100.tar.gz/download -O lame-3.100.tar.gz && \
    tar xf lame-3.100.tar.gz && \
    cd lame-3.100 && \
    ./configure --prefix=/usr/local --enable-static --disable-shared --disable-frontend --disable-decoder && \
    make -j4 && \
    make install && \
    cd .. && rm -rf lame-3.100 lame-3.100.tar.gz

# Build libopus (static)
RUN wget -q https://downloads.xiph.org/releases/opus/opus-1.5.2.tar.gz && \
    tar xf opus-1.5.2.tar.gz && \
    cd opus-1.5.2 && \
    ./configure --prefix=/usr/local --enable-static --disable-shared --disable-doc --disable-extra-programs && \
    make -j4 && \
    make install && \
    cd .. && rm -rf opus-1.5.2 opus-1.5.2.tar.gz

ENV PKG_CONFIG_PATH=/usr/local/lib/pkgconfig

# Build minimal FFmpeg 8.0 with libfdk-aac and libopus (nonfree license)
RUN wget -q https://ffmpeg.org/releases/ffmpeg-8.0.tar.xz && \
    tar xf ffmpeg-8.0.tar.xz && \
    cd ffmpeg-8.0 && \
    ./configure \
        --prefix=/usr/local \
        --pkg-config-flags="--static" \
        --enable-gpl \
        --enable-nonfree \
        --enable-static \
        --disable-shared \
        --disable-debug \
        --disable-doc \
        --disable-ffplay \
        --enable-ffprobe \
        --disable-swscale \
        --disable-everything \
        --enable-decoder=pcm_* \
        --enable-decoder=aac \
        --enable-decoder=mp3float \
        --enable-encoder=pcm_s16le \
        --enable-libfdk-aac \
        --enable-libmp3lame \
        --enable-libopus \
        --enable-encoder=libmp3lame \
        --enable-encoder=aac \
        --enable-encoder=libfdk_aac \
        --enable-encoder=libopus \
        --enable-decoder=libfdk_aac \
        --enable-decoder=libopus \
        --enable-demuxer=wav \
        --enable-demuxer=ffmetadata \
        --enable-demuxer=mov \
        --enable-demuxer=mp3 \
        --enable-demuxer=ogg \
        --enable-muxer=ogg \
        --enable-muxer=segment \
        --enable-muxer=mp4 \
        --enable-muxer=ipod \
        --enable-muxer=wav \
        --enable-muxer=mp3 \
        --enable-filter=afade \
        --enable-filter=asetrate \
        --enable-filter=aresample \
        --enable-filter=atempo \
        --enable-filter=areverse \
        --enable-filter=silenceremove \
        --enable-filter=concat \
        --enable-filter=apad \
        --enable-filter=loudnorm \
        --enable-filter=dynaudnorm \
        --enable-filter=volume \
        --enable-filter=alimiter \
        --enable-indev=lavfi \
        --enable-demuxer=concat \
        --enable-filter=anullsrc \
        --enable-protocol=file \
        --enable-protocol=pipe \
        --enable-protocol=cache \
        --enable-small \
        --enable-lto \
        --extra-cflags="-O3 -ffunction-sections -fdata-sections" \
        --extra-ldflags="-Wl,--gc-sections -Wl,--as-needed" && \
    make -j4 && \
    make install && \
    cd .. && rm -rf ffmpeg-8.0*

# Strip the static binaries to remove debug symbols
RUN strip --strip-all /usr/local/bin/ffmpeg /usr/local/bin/ffprobe

# Final stage: Copy only the binaries
FROM scratch AS final
COPY --from=ffmpeg-builder /usr/local/bin/ffmpeg /ffmpeg
COPY --from=ffmpeg-builder /usr/local/bin/ffprobe /ffprobe

# Set ffmpeg as the default entrypoint
ENTRYPOINT ["/ffmpeg"]