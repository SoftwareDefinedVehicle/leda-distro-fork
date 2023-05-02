#!/bin/sh

docker buildx ls
docker buildx create --use --name multi-arch-builder
docker buildx inspect --bootstrap

