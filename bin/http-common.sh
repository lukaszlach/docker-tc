#!/usr/bin/env bash
http_response() {
    if [ -z "$2" ]; then
        return
    fi
    echo -e "$2"
    # as any other exit code blocks sending the response
    exit 0
}
http_response_json() {
    # no way to send HTTP header currently
    http_response "$1" "$2"
}
http_safe_param() {
    RESULT="$1"
    RESULT=$(echo "'$RESULT'" | sed "s/[']//g")
    echo "$RESULT"
}