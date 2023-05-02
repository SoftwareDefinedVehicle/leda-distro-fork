#!/bin/sh

docker buildx build \
    --progress plain \
    --platform linux/arm64 \
    --builder multi-arch-builder \
    --tag eclipse-leda/raspi-core:latest \
    --file Dockerfile.raspi-core \
    --load \
    .
