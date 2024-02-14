#!/usr/bin/env bash
source "$SCRIPTS_PATH/000_Config.sh" > /dev/null 2>&1

EMAIL_POSTFIX="@snomed.org"
EMAIL_DELIMITER=","
STR=""

case $1 in
email)
    FIRST=true
    IFS='|' read -r -a EMAIL_LIST <<< "${SNOMED_PROJECT_NOTIFIED_USERS}"

    for id in "${EMAIL_LIST[@]}"; do
        if $FIRST; then
            FIRST=false
        else
            STR="${STR}${EMAIL_DELIMITER}"
        fi

        STR="${STR}${id}"

        if [[ ! $id =~ @ ]]; then
            STR="${STR}${EMAIL_POSTFIX}"
        fi
    done

    ;;
success)
    STR="#${SNOMED_PROJECT_SLACK_CHANNEL}"
    ;;
failure)
    STR="#${SNOMED_PROJECT_SLACK_CHANNEL}"
    ;;
esac

if [[ -z $STR ]]; then
    echo -n "#"
else
    echo -n "$STR"
fi
