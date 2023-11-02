#!/usr/bin/env bash
REQUEST=$1
METHOD=$(jq -r '.Method' <(echo "$REQUEST"))
URL=$(jq -r '.URL' <(echo "$REQUEST"))
URL_PATH=$(echo "$URL" | sed 's/\?.*$//')
ACTION="get"
PARAM1=$(echo "$URL_PATH" | cut -d/ -f2)
PARAM2=$(echo "$URL_PATH" | cut -d/ -f3)
BODY=$(jq -r '.Body' <(echo "$REQUEST"))
if [ ! -z "$BODY" ]; then
    # @todo merge with query, not overwrite
    QUERY="$BODY"
else
    QUERY=$(echo "$URL" | cut -d'?' -f2- | tr '&' $'\n')
fi
case "$METHOD" in
    INSPECT|GET)    METHOD=GET; ;;
    SET|POST)       METHOD=POST; ;;
    UNIGNORE|PUT)   METHOD=PUT; ;;
    IGNORE|DELETE)  METHOD=DELETE; ;;
esac
ACTION=$(echo "$METHOD" | tr '[:upper:]' '[:lower:]')
ACTION_SCRIPT="/docker-tc/bin/http-${ACTION}.sh"
if [ ! -f "$ACTION_SCRIPT" ]; then
    echo "Error: File $ACTION_SCRIPT not found"
    exit 1
fi
bash "$ACTION_SCRIPT" "$PARAM1" "$PARAM2" "$QUERY"
