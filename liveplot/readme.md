# Liveplot Demo

The liveplot demo shows a visualization of VSS signals running on a dockerized Leda/QEMU image.
The setup is meant to be run inside of a GitHub Codespaces DevContainer with a virtual XServer and forwarding a VNC port to the user's workstation.

# Setup

in devcontainer.json, add the desktop.lite feature and forward VNC port:

"features": {
		"docker-in-docker": "latest",
		"github-cli": "latest",
		"ghcr.io/devcontainers/features/desktop-lite:1": {}
	},
	"forwardPorts": [6080],
    "portsAttributes": {
     "6080": {
       "label": "desktop"
    }

install python3-tk
    sudo apt-get update
    sudo apt-get install -y python3-tk

run leda with exposed databroker port
    https://eclipse-leda.github.io/leda/docs/app-deployment/carsim/#getting-started
    sudo chmod a+rwx /dev/kvm
    docker run -it --privileged -p 30555:30555 -p 2222:2222 ghcr.io/eclipse-leda/leda-distro/leda-quickstart-x86

run liveplot
    mkdir liveplot
    cd liveplot
    git clone https://github.com/vasilvas99/vss-live-plot
    cd vss-live-plot
    pip install -r requirements.txt
    export DISPLAY=:1.0
    ./vss-live-plot.py Vehicle.Speed -d localhost:30555
    ./vss-live-plot.py Vehicle.Chassis.SteeringWheel.Angle -d localhost:30555

install carsim
    from https://eclipse-leda.github.io/leda/docs/app-deployment/carsim/#getting-started
    login to leda

    kanto-cm create --name carsim --e=DATABROKER_ADDRESS=databroker:55555 --hosts="databroker:container_databroker-host" ghcr.io/eclipse-leda/leda-example-applications/leda-example-carsim:v0.0.1
    kanto-cm start --name carsim

kanto-cm create --name driversim --e=DATABROKER_ADDRESS=databroker:55555 --hosts="databroker:container_databroker-host" ghcr.io/eclipse-leda/leda-example-applications/leda-example-driversim:v0.0.1
kanto-cm start --name driversim

