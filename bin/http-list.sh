#!/usr/bin/env bash
. /docker-tc/bin/docker-common.sh
. /docker-tc/bin/http-common.sh
RESULT=
append_result() { RESULT="$RESULT"$*"\n"; }
while IFS=" " read -r CONTAINER_ID CONTAINER_NAME; do
    append_result "# id=$CONTAINER_ID name=$CONTAINER_NAME"
    CONTAINER_NETWORKS=$(docker_container_get_networks "$CONTAINER_ID")
    while read NETWORK_ID; do
        NETWORK_INTERFACE_NAMES=$(docker_container_interfaces_in_network "$CONTAINER_ID" "$NETWORK_ID")
        if [ -z "$NETWORK_INTERFACE_NAMES" ]; then
            continue
        fi
        append_result "# network=$NETWORK_ID"
        while IFS= read -r NETWORK_INTERFACE_NAME; do
            #append_result $(tc qdisc show dev "$NETWORK_INTERFACE_NAME" 2>&1) "\n"
            RESULT="$RESULT$(tc qdisc show dev "$NETWORK_INTERFACE_NAME" 2>&1)\n"
        done < <(echo -e "$NETWORK_INTERFACE_NAMES")
    done < <(echo -e "$CONTAINER_NETWORKS")
done < <(docker ps --format '{{ .ID }} {{ .Names }}')
http_response 200 "$RESULT"
