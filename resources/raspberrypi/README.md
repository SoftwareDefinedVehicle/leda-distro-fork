# Leda Containers for use on Raspberry Pi

The containers which can be built using the Dockerfiles in this directory enable Raspberry Pi specific functionality,
such as drivers for additional hardware extensions (LCD Displays, CAN HATs, GPS/GSM/GNSS piggy backs etc.).

Some hardware runs out of the box (CAN HAT), as they only need Kernel modules which are already built in the Leda kernel.

Other hardware require additional libraries.

These containers are meant as ad-hoc installation on the standard Leda quickstart image to enable that functionality.

Typical steps:
- Leda dev team designs the Docker container with all the necessary libraries and initialization steps
- Leda dev team builds and releases the Docker container
- Leda dev team provides a .json container descriptor for deployment, which is pre-installed but disabled
- User re-enables the container descriptor by renaming the fil to .json and restarts kanto-auto-deployer
- User may need to reboot Raspberry Pi in case there are changes to config.txt necessary
- Container gets deployed, libraries are initiated.

## Open questions and tasks

- Implement a utility to modify the config.txt, so that a container can "request" changes to config.txt
- The utility needs to manage the changes somehow, e.g. when a container is undeployed the config.txt change should be rolled back?
- How can the container indicate to the user that a reboot is necessary? Should we do that semi-automatically? ("The system has changed. Please reboot")
- Should we introduce some kind of descriptor inside of containers to "ask" before applying changes. E.g. the container could contain the necessary modification to config.txt or describe which dtoverlay are necessary etc.

## Building containers for Raspberry Pi with Docker

docker buildx ls
docker buildx create --use --name multi-arch-builder
docker buildx inspect --bootstrap
docker buildx build --platform linux/arm64 -t eclipse-leda/raspi-core:latest -f Dockerfile.raspi-core .
docker buildx imagetools inspect eclipse-leda/raspi-core:latest

## Dockerfiles Base Images

To build the containers, we need to decide on which base images to use.

A Raspberry-Pi specific base image (e.g. Raspbian) would be great, as it already contains raspi-specific utilities.

Many user manuals of hardware extensions expect the base OS to be Raspbian or at least Debian based.
  We want to design our Dockerfiles that can be easily understood and maintained.
  We want to achieve this by following the installation steps from the user manual as much as possible.

Balena is publishing great base images and they already have put lots of efforts into making them convenient to use.

So we decided to use the base images from Balena:

```plain
# For the building stage (eg heavier and includes gcc)
balenalib/raspberrypi4-64-debian:build

# For the run stage (eg smaller and does not contain build tools)
balenalib/raspberrypi4-64-debian:run
```

Required changes to the steps include:

- Adding additional development libraries, such as `python3-dev` to fix build errors
- Modifying installation of full packages and use smaller packages (e.g. replacing `git-all` with `git`)
- Using different locations for user homes or other user-specific assumptions
  - Cloning into specific, absolute paths instead of user home (`~`)

## Container Runtime Configuratin for GPIO

There are three ways to let a container access GPIO:

1. *Recommended:* Adding the /dev/gpiomem device, e.g. `docker run --device /dev/gpiomem -d myapp` or `...` in Kanto Container Configuration
2. Run in privileged mode, e.g. `docker run --privileged -d myapp` or `privileged: true` in Kanto Container Configuration
3. Using the sysfs filesystem on the host, e.g. `docker run -v /sys:/sys -d myapp` or `...` in Kanto Container Configuration

The first option has the best performance (compared to sysfs) and only gives fine-grained access to the container.
Unfortunately, not all libraries support of three options, which may require making a tradeoff decision.

> Note: `libgpiod` may require to map `/dev/gpiochip0`

## Executing container on x86 hosts

Some libraries, such as RPi.GPIO are trying to detect the Raspberry Pi CPU and exit if they are run on different boards.

For development and testing purposes, we want to be able to emulate the Raspberry Pi CPU Information
and run the containers on an x86 hosts using QEMU.

To fake the cpuinfo, we need to mount `/proc/cpuinfo` to a pre-generated static file,
which was generated on the actual target hardware.

The `/dev/gpiomem` device is created by the BCM2835 device driver and unavailable on x86 hosts.
To simulate that, we just create the node manually using `mknod`:

```plain
# crw------- 1 root root 244, 0 Apr 20 11:14 /dev/gpiomem

sudo mknod --mode=0600 /dev/gpiomem c 244 0
```

## Joy-IT LCD Display 20x4 with 4 Buttons

Connected to GPIO, the extension provides a small display and buttons for interactions.
The use case of Leda is to display a VSS signal value and let the user interact with a vehicle service, such as adjusting the seat position.

Product website: https://www.joy-it.net/en/products/RB-LCD-20x4
User manual: https://www.joy-it.net/files/files/Produkte/RB-LCD-20x4/RB-LCD-16x2-20x4_Manual_2022-02-22.pdf

The Dockerfile.joy-it-lcd-display-20x4 describes the installation of the libraries based on the manufacturers user manual.


