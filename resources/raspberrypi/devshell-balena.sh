#!/bin/sh

docker run --privileged --rm tonistiigi/binfmt --install arm64
docker run -it --rm balenalib/raspberrypi4-64-debian:build /bin/bash
