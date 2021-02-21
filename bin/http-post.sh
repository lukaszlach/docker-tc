#!/usr/bin/env bash
. /docker-tc/bin/docker-common.sh
. /docker-tc/bin/http-common.sh
. /docker-tc/bin/tc-common.sh
. /docker-tc/bin/core.sh
CONTAINER_ID=$(http_safe_param "$1")
NETWORK_NAME=$(http_safe_param "$2")
QUERY="$3"
if ! docker_container_is_running "$CONTAINER_ID"; then
    http_response 400 "$CONTAINER_ID is not running"
fi
CONTAINER_ID=$(docker_container_get_short_id "$CONTAINER_ID")
NETM_OPTIONS=
TBF_OPTIONS=
OPTIONS_LOG=
while read QUERY_PARAM; do
    FIELD=$(echo "$QUERY_PARAM" | cut -d= -f1)
    VALUE=$(echo "$QUERY_PARAM" | cut -d= -f2-)
    FIELD=$(http_safe_param "$FIELD")
    VALUE=$(echo "$VALUE" | sed 's/[^a-zA-Z0-9%-_]//g')
    case "$FIELD" in
        delay|loss|corrupt|duplicate|reorder)
            NETM_OPTIONS+="$FIELD $VALUE "
            ;;
        rate)
            TBF_OPTIONS+="$FIELD $VALUE "
            ;;
        *)
            echo "Error: Invalid field $FIELD"
            exit 1
            ;;
    esac
    OPTIONS_LOG+="$FIELD=$VALUE, "
done < <(echo "$QUERY" | tr '&' $'\n')
if [ -z "$NETM_OPTIONS" ] && [ -z "$TBF_OPTIONS" ]; then
    echo "Notice: Nothing to do"
    exit 0
fi
OPTIONS_LOG=$(echo "$OPTIONS_LOG" | sed 's/[, ]*$//')
CONTAINER_NETWORKS=$(docker_container_get_networks "$CONTAINER_ID")
while read NETWORK_ID; do
    NETWORK_INTERFACE_NAMES=$(docker_container_interfaces_in_network "$CONTAINER_ID" "$NETWORK_ID")
    if [ -z "$NETWORK_INTERFACE_NAMES" ]; then
        continue
    fi
    if [ -z "$NETWORK_NAME" ] || [ "$NETWORK_NAME" == "$NETWORK_ID" ]; then
        echo "[DEBUG] $NETWORK_NAME match $NETWORK_ID"
        while IFS= read -r NETWORK_INTERFACE_NAME; do
            tc_init
            qdisc_del "$NETWORK_INTERFACE_NAME"
            if [ ! -z "$NETM_OPTIONS" ]; then
                qdisc_netm "$NETWORK_INTERFACE_NAME" $NETM_OPTIONS
            fi
            if [ ! -z "$TBF_OPTIONS" ]; then
                qdisc_tbf "$NETWORK_INTERFACE_NAME" $TBF_OPTIONS
            fi
            echo "Set ${OPTIONS_LOG} on $NETWORK_INTERFACE_NAME"
            echo "Controlling traffic of the container $(docker_container_get_name "$CONTAINER_ID") on $NETWORK_INTERFACE_NAME"
        done < <(echo -e "$NETWORK_INTERFACE_NAMES")
    fi
done < <(echo -e "$CONTAINER_NETWORKS")
block "$CONTAINER_ID"
http_response 200
