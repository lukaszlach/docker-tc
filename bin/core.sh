#!/usr/bin/env bash
BASE_LABEL="com.docker-tc"
SCAN_INTERVAL="${SCAN_INTERVAL:-2s}"
GC_INTERVAL="5m"

DATA_DIR=/var/docker-tc
CONTAINER_LOCKS_DIR="$DATA_DIR/container-locks"

lock() {
    touch "$CONTAINER_LOCKS_DIR/$1.lock"
}
block() {
    touch "$CONTAINER_LOCKS_DIR/$1.block"
}
unlock() {
    rm -f \
        "$CONTAINER_LOCKS_DIR/$1.lock" \
        "$CONTAINER_LOCKS_DIR/$1.block"
}
is_locked() {
    test -f "$CONTAINER_LOCKS_DIR/$1.lock" || \
    test -f "$CONTAINER_LOCKS_DIR/$1.block"
}