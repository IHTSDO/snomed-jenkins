#!/usr/bin/env bash
source "$SCRIPTS_PATH/000_Config.sh" > /dev/null 2>&1

EMAIL_POSTFIX="@snomed.org"
EMAIL_DELIMITER=","
STR=""
channelName=$1

case $channelName in
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
success|failure)
    # Slacksend can take ";", "," or space separated list of slack channels.
    # See:  https://www.jenkins.io/doc/pipeline/steps/slack/
    # For consistency use pipe in the CSV, to seperate a slack channel list.
    STR="#${SNOMED_PROJECT_SLACK_CHANNEL//|/ }"
    ;;
*)
    echo "Unknown command $channelName"
    exit 1
esac

if [[ -z $STR ]]; then
    echo -n "#"
else
    echo -n "$STR"
fi
