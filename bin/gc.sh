#!/usr/bin/env bash
. /docker-tc/bin/core.sh
while true; do
    find "$CONTAINER_LOCKS_DIR" \
        -mmin "+$((60*60*12))" \
        -type f \
        -name "*.lock" \
        -delete
    sleep "$GC_INTERVAL"
done