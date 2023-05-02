#!/bin/sh

docker run --privileged --rm tonistiigi/binfmt --install arm64

# Run the docker container (which was built for ARM64)
# on x86 host. Fake some of the hardware, such as CPU Info
# and memory and GPIO access.

# sudo mknod --mode=0600 /dev/gpiomem c 244 0

docker run -it --rm \
    --volume $(pwd)/proc-cpuinfo-raspi4.txt:/proc/cpuinfo \
    --cap-add SYS_RAWIO \
    --device /dev/mem \
    --device /dev/gpiomem \
    eclipse-leda/raspi-core
