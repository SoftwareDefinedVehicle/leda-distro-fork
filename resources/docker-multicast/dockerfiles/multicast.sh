#!/bin/bash

function log() {
    MESSAGE="$1"
    echo "Leda-Multicaster: $1"
}

if [ -z "$1" ] || [ "$1" == "--help" ]; then
    log "$0 <networkdevice>"
    exit 1
fi

NETWORK_INTERFACE="${1:-leda1}"
VIRTUAL_NETWORK=""

log "Using network interface: ${NETWORK_INTERFACE}"

function checkNetworkInterface() {
    log "Checking if network interface exists: ${NETWORK_INTERFACE}"
    if [ -d /sys/class/net/${NETWORK_INTERFACE} ]; then
        log "OK: Network interface exists"
    else
        log "WARNING: Network interface does not exist, creating a virtual one"
        VIRTUAL_NETWORK=${NETWORK_INTERFACE}
        ip link add ${VIRTUAL_NETWORK} type dummy
        #ip link add link ${VIRTUAL_NETWORK} address 00:11:11:11:11:11 ${VIRTUAL_NETWORK} type macvlan
        ip addr add 192.168.123.123/24 brd + dev ${VIRTUAL_NETWORK}
    fi

    log "Checking if network interface is up: ${NETWORK_INTERFACE}"
    OUTPUT=$(cat /sys/class/net/${NETWORK_INTERFACE}/operstate)
    if echo "$OUTPUT" | grep -q 'up'; then
        log "OK: Network interface ${NETWORK_INTERFACE} is up"
    else
        log "WARNING: Network interface ${NETWORK_INTERFACE} is not up, but state is ${OUTPUT}, trying to bring up"
        ip link set dev ${NETWORK_INTERFACE} up
        RC=$?
        if [ $RC -eq 0 ]; then
            log "OK: Brought network interface ${NETWORK_INTERFACE} up"
        else
            log "ERROR: Unable to bring network interface ${NETWORK_INTERFACE} up, error code ${RC}"
        fi
    fi
}

function checkTools() {
    log "Checking tools"

    if ! command -v sysctl; then 
        log "ERROR: sysctl missing"
        exit 1
    fi

    if ! command -v ip; then 
        log "ERROR: ip missing"
        exit 1
    fi

    if ! command -v ping; then 
        log "ERROR: ping missing"
        exit 1
    fi

    if ! command -v grep; then 
        log "ERROR: grep missing"
        exit 1
    fi
}

function setSystemSetting() {
    # Example: setSystemSetting "net.ipv4.ip_forward" "1"
    KEY="$1"
    EXPECTED_VALUE="$2"
    CURRENT_VALUE=$(sysctl -n ${KEY})
    if [ ! "${CURRENT_VALUE}" -eq ${EXPECTED_VALUE} ]; then
        log "WARNING: ${KEY} is currently ${CURRENT_VALUE}, but should be ${EXPECTED_VALUE}. Trying to set value..."
        sysctl -w ${KEY}=${EXPECTED_VALUE}
        RC=$?
        if [ $RC -eq 0 ]; then
            log "OK: ${KEY} has been set to expected value: ${EXPECTED_VALUE}"
        else
            log "ERROR: Could not set ${KEY} to ${EXPECTED_VALUE}, sysctl error code: $RC"
        fi
    else
        log "OK: ${KEY} is already set to expected value: ${EXPECTED_VALUE}"
    fi
}

function checkIPForward() {
    log "Checking Linux kernel setting: IP forwarding (IPv4)"
    setSystemSetting "net.ipv4.ip_forward" "1"
}

function checkICMPEcho() {
    log "Enabling IPv4 ICMP echo for broadcast or multicast (for testing purposes)"
    setSystemSetting "net.ipv4.icmp_echo_ignore_broadcasts" "0"
}

function checkMulticast() {
    OUTPUT=$(ip -o link show dev ${NETWORK_INTERFACE})
    if echo "$OUTPUT" | grep -q 'MULTICAST'; then
        log "OK: Multicast already enabled on link ${NETWORK_INTERFACE}"
    else
        log "Enabling multicast on network interface: ${NETWORK_INTERFACE}"
        ip link set dev ${NETWORK_INTERFACE} multicast on
        RC=$?
        if [ $RC -eq 0 ]; then
            log "OK: Enabling multicast succeeded"
        else
            log "ERROR: Unable to enable multicast, error code $RC"
            exit 1
        fi
    fi
}

function checkRouting() {
    TARGET_GROUP="$1"
    EXPECTED_NETWORK_DEVICE="$2"
    log "Checking route to ${TARGET_GROUP} going through network device ${EXPECTED_NETWORK_DEVICE}"
    OUTPUT=$(ip -o route get ${TARGET_GROUP})
    if echo "$OUTPUT" | grep -q "${EXPECTED_NETWORK_DEVICE}"; then
        log "OK: Route for ${TARGET_GROUP} is going through expected network interface ${EXPECTED_NETWORK_DEVICE}"
    else
        log "WARNING: Route for ${TARGET_GROUP} is NOT going through network interface ${EXPECTED_NETWORK_DEVICE}"
        ACTUAL_NETWORK_DEVICE_ROUTE=$(ip -o route get ${TARGET_GROUP})
        log "WARNING: Route for ${TARGET_GROUP} is going through network interface: ${ACTUAL_NETWORK_DEVICE_ROUTE}"
        log "Adding route for specific target group: ${TARGET_GROUP} for device ${EXPECTED_NETWORK_DEVICE}"
        ip route add ${TARGET_GROUP} dev ${EXPECTED_NETWORK_DEVICE}
        RC=$?
        if [ $RC -eq 0 ]; then
            log "OK: Route added"
        else
            log "ERROR: Unable to add route, error code $RC"
            exit 1
        fi
    fi
}

function checkSetup() {
    checkNetworkInterface
    checkIPForward
    checkICMPEcho
    checkMulticast
    checkRouting "224.0.0.1" "${NETWORK_INTERFACE}"
}

function joinMulticastGroup() {
    log "Checking if multicast group is already joined"
    OUTPUT=$(ip -o addr show dev ${NETWORK_INTERFACE})
    OUTPUT2=$(ip maddr show dev ${NETWORK_INTERFACE})
    if echo "$OUTPUT" | grep -q '239.0.0.123'; then
        log "OK: Multicast address already joined (ip addr show)"

        if echo "$OUTPUT2" | grep -q '239.0.0.123'; then
            log "OK: Multicast address already joined (ip maddr show)"
        else
            log "Warning: Multicast address already joined (ip maddr show)"
        fi
    else
        log "Joining multicast address 239.0.0.123"
        ip addr add 239.0.0.123/32 dev ${NETWORK_INTERFACE} autojoin
        RC=$?
        if [ $RC -eq 0 ]; then
            log "OK: Joined multicast address"
        else
            log "ERROR: Unable to join multicast address, error code $RC"
        fi
    fi
}

function runTestLoop() {
    # Example: runTestLoop "224.0.0.1"
    TARGET="$1"
    log "Running test loop for ${TARGET}"
    ping -I ${NETWORK_INTERFACE} -4 -c 5 ${TARGET}
    RC=$?
    if [ $RC -eq 0 ]; then
        log "OK: Multicast ping echo received for ${TARGET}"
    else
        log "ERROR: No Multicast ping echoes received for ${TARGET}, error code $RC"
    fi
}

function mainLoop() {
    checkSetup
    runTestLoop "224.0.0.1"

    joinMulticastGroup
    runTestLoop "239.0.0.123"
}

function leaveMulticastGroup() {
    log "Leaving multicast group"
    ip addr del 239.0.0.123/32 dev ${NETWORK_INTERFACE} autojoin
    RC=$?
    if [ $RC -eq 0 ]; then
        log "OK: Left multicast address"
    else
        log "ERROR: Unable to leave multicast address, error code $RC"
    fi
}

function removeVirtualNetwork() {
    if [ -z "${VIRTUAL_NETWORK}" ]; then
        log "No virtual network interface to remove"
    else
        log "Removing virtual network interface ${VIRTUAL_NETWORK}"
        ip link delete dev ${VIRTUAL_NETWORK}
    fi
}

function gracefulShutdown() {
    leaveMulticastGroup
    removeVirtualNetwork
}

checkTools

trap gracefulShutdown EXIT
#while true
#do
    mainLoop
#    sleep 5
#done

