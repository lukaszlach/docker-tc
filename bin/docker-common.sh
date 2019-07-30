#!/usr/bin/env bash
docker_container_is_running() {
    docker ps --format '{{ .ID }}|{{ .Names }}|' | grep -q "$1|"
}
docker_container_get_networks() {
    docker inspect \
        --format '{{ json .NetworkSettings.Networks }}' \
        "$1" | \
        jq -r '. | keys | join("\n")'
}
docker_container_get_id() {
    docker inspect --format '{{ .Id }}' "$1"
}
docker_container_get_short_id() {
    docker_container_get_id "$1" | head -c 12
}
docker_id_long_to_short() {
    echo "$1" | head -c 12
}
docker_container_get_name() {
    docker inspect --format '{{ .Name }}' "$1"
}
docker_container_get_interfaces() {
    IFLINKS=$(docker exec $1 sh -c 'cat /sys/class/net/*/iflink')
    if [ -z "$IFLINKS" ]; then
        return 1
    fi
    RESULT=""
    while IFS= read -r IFLINK; do
        if [[ "$IFLINK" -gt "1" ]]; then
            IFACE=$(grep -l $IFLINK /sys/class/net/veth*/ifindex | sed -e 's;^.*net/\(.*\)/ifindex$;\1;')
            if [ -n "$IFACE" ]; then
                RESULT+="${IFACE}\n"
            fi
        fi
    done < <(echo -e "$IFLINKS")
    echo "${RESULT::-2}"
}
docker_network_get_interfaces() {
    NETWORK_ID=$(docker network inspect --format '{{ .Id }}' "$1")
    SHORT_NETWORK_ID=$(echo -n "$NETWORK_ID" | head -c 12)
    NETWORK_INTERFACE_NAMES=$(ip a | grep -E "veth.*br-$SHORT_NETWORK_ID" | grep -o 'veth[^@]*' || :)
    if [ -z "$NETWORK_INTERFACE_NAMES" ]; then
        return 1
    fi
    echo "$NETWORK_INTERFACE_NAMES"
}
docker_container_interfaces_in_network() {
    CONTAINER_INTERFACES=$(docker_container_get_interfaces "$1")
    NETWORK_INTERFACES=$(docker_network_get_interfaces "$2")
    COMMON_INTERFACES=""
    while IFS= read -r NETWORK_IFACE; do
        while IFS= read -r CONTAINER_IFACE; do
            if [ "$NETWORK_IFACE" = "$CONTAINER_IFACE" ]; then
                COMMON_INTERFACES+="${CONTAINER_IFACE}\n"
            fi
        done < <(echo -e "$CONTAINER_INTERFACES")
    done < <(echo -e "$NETWORK_INTERFACES")
    echo "${COMMON_INTERFACES::-2}"
}
CONTAINER_LABELS=
docker_container_labels_load() {
    CONTAINER_LABELS=$(docker inspect --format '{{ json .Config.Labels }}' "$1")
}
docker_container_labels_get() {
    jq -r ".[\"$1\"] | select (. != null)" <(echo "$CONTAINER_LABELS")
}