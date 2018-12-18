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
docker_network_get_interface() {
    NETWORK_ID=$(docker network inspect --format '{{ .Id }}' "$1")
    SHORT_NETWORK_ID=$(echo -n "$NETWORK_ID" | head -c 12)
    NETWORK_INTERFACE_NAME=$(ip a | grep -E "veth.*br-$SHORT_NETWORK_ID" | grep -o 'veth[^@]*' || :)
    if [ -z "$NETWORK_INTERFACE_NAME" ]; then
        return 1
    fi
    echo "$NETWORK_INTERFACE_NAME"
}
CONTAINER_LABELS=
docker_container_labels_load() {
    CONTAINER_LABELS=$(docker inspect --format '{{ json .Config.Labels }}' "$1")
}
docker_container_labels_get() {
    jq -r ".[\"$1\"] | select (. != null)" <(echo "$CONTAINER_LABELS")
}