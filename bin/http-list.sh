#!/usr/bin/env bash
. /docker-tc/bin/docker-common.sh
. /docker-tc/bin/http-common.sh
RESULT=
append_result() { RESULT="$RESULT"$*"\n"; }
while IFS=" " read -r CONTAINER_ID CONTAINER_NAME; do
    append_result "# id=$CONTAINER_ID name=$CONTAINER_NAME"
    CONTAINER_NETWORKS=$(docker_container_get_networks "$CONTAINER_ID")
    while read NETWORK_ID; do
        NETWORK_INTERFACE_NAME=$(docker_network_get_interface "$NETWORK_ID")
        if [ -z "$NETWORK_INTERFACE_NAME" ]; then
            continue
        fi
        #append_result $(tc qdisc show dev "$NETWORK_INTERFACE_NAME" 2>&1) "\n"
        RESULT="$RESULT$(tc qdisc show dev "$NETWORK_INTERFACE_NAME" 2>&1)\n"
    done < <(echo -e "$CONTAINER_NETWORKS")
done < <(docker ps --format '{{ .ID }} {{ .Names }}')
http_response 200 "$RESULT"
