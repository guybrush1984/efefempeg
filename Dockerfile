FROM python:3.11-slim AS ffmpeg-builder

# Install build dependencies for FFmpeg
RUN apt-get update && apt-get install -y --no-install-recommends \
    build-essential \
    wget \
    yasm \
    nasm \
    pkg-config \
    ca-certificates \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /build

# Build minimal FFmpeg 8.0 with native AAC encoder (LGPL license)
RUN wget -q https://ffmpeg.org/releases/ffmpeg-8.0.tar.xz && \
    tar xf ffmpeg-8.0.tar.xz && \
    cd ffmpeg-8.0 && \
    ./configure \
        --prefix=/usr/local \
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
        --enable-encoder=pcm_s16le \
        --enable-encoder=aac \
        --enable-demuxer=wav \
        --enable-demuxer=ffmetadata \
        --enable-demuxer=mov \
        --enable-muxer=segment \
        --enable-muxer=mp4 \
        --enable-muxer=ipod \
        --enable-muxer=wav \
        --enable-filter=asetrate \
        --enable-filter=aresample \
        --enable-filter=atempo \
        --enable-filter=areverse \
        --enable-filter=silenceremove \
        --enable-filter=concat \
        --enable-filter=apad \
        --enable-filter=loudnorm \
        --enable-indev=lavfi \
        --enable-demuxer=concat \
        --enable-filter=anullsrc \
        --enable-protocol=file \
        --enable-protocol=pipe \
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