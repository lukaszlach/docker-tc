#!/usr/bin/env bash
. /docker-tc/bin/docker-common.sh
. /docker-tc/bin/http-common.sh
CONTAINER_ID=$(http_safe_param "$1")
NETWORK_NAME=$(http_safe_param "$2")
if ! docker_container_is_running "$CONTAINER_ID"; then
    http_response 400 "$CONTAINER_ID is not running"
fi
CONTAINER_NETWORKS=$(docker_container_get_networks "$CONTAINER_ID")
RESULT=
while read NETWORK_ID; do
    NETWORK_INTERFACE_NAMES=$(docker_container_interfaces_in_network "$CONTAINER_ID" "$NETWORK_ID")
    if [ -z "$NETWORK_INTERFACE_NAMES" ]; then
        continue
    fi
    if [ -z "$NETWORK_NAME" ] || [ "$NETWORK_NAME" == $NETWORK_ID ]; then
        while IFS= read -r NETWORK_INTERFACE_NAME; do
            RESULT="$RESULT$(tc qdisc show dev "$NETWORK_INTERFACE_NAME" 2>&1)"
        done < <(echo -e "$NETWORK_INTERFACE_NAMES")
    fi
done < <(echo -e "$CONTAINER_NETWORKS")
http_response 200 "$RESULT"
