#!/usr/bin/env bash
source ../_PipelineCreationJob_/000_Config.sh > /dev/null 2>&1

EMAIL_POSTFIX="@snomed.org"
EMAIL_DELIMITER=","

case $1 in
email)
    FIRST=true
    IFS='|' read -r -a EMAIL_LIST <<< "${SNOMED_PROJECT_NOTIFIED_USERS}"

    for id in "${EMAIL_LIST[@]}"; do
        if $FIRST; then
            FIRST=false
        else
            echo -n "${EMAIL_DELIMITER}"
        fi

        if [[ $id =~ @ ]]; then
            echo -n "${id}"
        else
            echo -n "${id}${EMAIL_POSTFIX}"
        fi
    done
    ;;
success)
    echo -n "#${SNOMED_PROJECT_SLACK_CHANNEL}"
    ;;
failure)
    echo -n "#${SNOMED_PROJECT_SLACK_CHANNEL}"
    ;;
esac
