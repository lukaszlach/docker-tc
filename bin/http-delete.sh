#!/usr/bin/env bash
. /docker-tc/bin/docker-common.sh
. /docker-tc/bin/http-common.sh
. /docker-tc/bin/tc-common.sh
. /docker-tc/bin/core.sh
CONTAINER_ID=$(http_safe_param "$1")
if ! docker_container_is_running "$CONTAINER_ID"; then
    http_response 400 "$CONTAINER_ID is not running"
fi
CONTAINER_ID=$(docker_container_get_short_id "$CONTAINER_ID")
CONTAINER_NETWORKS=$(docker_container_get_networks "$CONTAINER_ID")
while read NETWORK_ID; do
    NETWORK_INTERFACE_NAME=$(docker_network_get_interface "$NETWORK_ID")
    if [ -z "$NETWORK_INTERFACE_NAME" ]; then
        continue
    fi
    qdisc_del "$NETWORK_INTERFACE_NAME"
done < <(echo -e "$CONTAINER_NETWORKS")
block "$CONTAINER_ID"
http_response 200
