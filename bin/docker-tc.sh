#!/usr/bin/env bash
. /docker-tc/bin/core.sh
. /docker-tc/bin/docker-common.sh
. /docker-tc/bin/tc-common.sh
set -e
log() {
    echo "[$(date -Is)] [$CONTAINER_ID] $*"
}
while read DOCKER_EVENT; do
    # docker events
    CONTAINER_ID=$(echo "$DOCKER_EVENT" | cut -d' ' -f4)
    if [ -z "$CONTAINER_ID" ]; then
        # docker ps -q
        CONTAINER_ID="$DOCKER_EVENT"
        if [ -z "$CONTAINER_ID" ]; then
            log "Error: Invalid payload"
            continue
        fi
    else
        # docker events
        # could have used docker_id_long_to_short although it is less safe
        CONTAINER_ID=$(docker_container_get_short_id "$CONTAINER_ID")
    fi
    if is_locked "$CONTAINER_ID"; then
        continue
    fi
    docker_container_labels_load "$CONTAINER_ID"
    if [[ "$(docker_container_labels_get "$BASE_LABEL.enabled")" == "0" ]]; then
        lock "$CONTAINER_ID"
        log "Notice: Skipping container, service was disabled by label"
        continue
    fi
    if [[ "$(docker_container_labels_get "$BASE_LABEL.enabled")" != "1" ]]; then
        lock "$CONTAINER_ID"
        log "Notice: Skipping container, no valid labels found"
        continue
    fi
    NETWORK_NAMES=$(docker_container_get_networks "$CONTAINER_ID")
    if [[ "$NETWORK_NAMES" == *"\n"* ]]; then
        log "Warning: Container is connected to multiple networks"
    fi
    while read NETWORK_NAME; do
        NETWORK_INTERFACE_NAME=$(docker_network_get_interface "$NETWORK_NAME")
        if [ -z "$NETWORK_INTERFACE_NAME" ]; then
            log "Warning: Network has no corresponding virtual network interface"
            lock "$CONTAINER_ID"
            continue
        fi
        LIMIT=$(docker_container_labels_get "$BASE_LABEL.limit")
        DELAY=$(docker_container_labels_get "$BASE_LABEL.delay")
        LOSS=$(docker_container_labels_get "$BASE_LABEL.loss")
        CORRUPT=$(docker_container_labels_get "$BASE_LABEL.corrupt")
        DUPLICATION=$(docker_container_labels_get "$BASE_LABEL.duplicate")
        REORDERING=$(docker_container_labels_get "$BASE_LABEL.reorder")
        tc_init
        qdisc_del "$NETWORK_INTERFACE_NAME" &>/dev/null || true
        OPTIONS_LOG=
        NETM_OPTIONS=
        netm_add_rule() {
            if [ ! -z "$2" ]; then
                OPTIONS_LOG+="$3=$2, "
                NETM_OPTIONS+="$1 $2 "
            fi
        }
        netm_add_rule "delay" "$DELAY" "delay"
        netm_add_rule "loss random" "$LOSS" "loss"
        netm_add_rule "corrupt" "$CORRUPT" "corrupt"
        netm_add_rule "duplicate" "$DUPLICATION" "duplicate"
        netm_add_rule "reorder" "$REORDERING" "reorder"
        OPTIONS_LOG=$(echo "$OPTIONS_LOG" | sed 's/[, ]*$//')
        log "Set ${OPTIONS_LOG} on $NETWORK_INTERFACE_NAME"
        qdisc_netm "$NETWORK_INTERFACE_NAME" $NETM_OPTIONS
        if [ ! -z "$LIMIT" ]; then
            log "Set bandwidth-limit=$LIMIT on $NETWORK_INTERFACE_NAME"
            qdisc_tbf "$NETWORK_INTERFACE_NAME" rate "$LIMIT"
        fi
        lock "$CONTAINER_ID"
        log "Controlling traffic of the container $(docker_container_get_name "$CONTAINER_ID") on $NETWORK_INTERFACE_NAME"
    done < <(echo -e "$NETWORK_NAMES")
done < <(
    docker ps -q;
    docker events --filter event=start | head -n1
)
