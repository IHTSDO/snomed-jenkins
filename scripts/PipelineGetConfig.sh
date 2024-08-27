#!/usr/bin/env bash
source "$SCRIPTS_PATH/000_Config.sh" > /dev/null 2>&1

# Local config.
EMAIL_POSTFIX="@snomed.org"
EMAIL_DELIMITER=","
configRequired=$1

# Example values for developing locally, make sure these are commented out before pushing.
#SNOMED_PROJECT_NOTIFIED_USERS="tom|dick@example.com|harry"
#GIT_BRANCH=develop
#SNOMED_PROJECT_DEPLOY_ENABLED=TRUE
#SNOMED_PROJECT_DEPLOY_CONFIG="rundeck:A:|rundeck:develop:332c2a5c-007b-40d3-a250-ef918822ddd2|rundeck:uat:uat-uuid|rundeck:prod:prod-uuid"
#SNOMED_PROJECT_SLACK_CHANNEL="#channela|#channelb"

# Create list of comma separated emails.
# Converts abc|def|jo@example.org to abc@snomed.org,def@snomed.org,jo@example.org
getEmailList() {
    IFS='|' read -r -a EMAIL_LIST <<< "${SNOMED_PROJECT_NOTIFIED_USERS}"
    local FIRST=true

    for email in "${EMAIL_LIST[@]}"; do
        if $FIRST; then
            FIRST=false
        else
            echo -n "${EMAIL_DELIMITER}"
        fi

        # Do we need to append "@snomed.org" to make it a valid email?
        if [[ $email =~ @ ]]; then
            echo -n "${email}"
        else
            echo -n "${email}${EMAIL_POSTFIX}"
        fi
    done
}

getRundeckConfig() {
    if [[ $SNOMED_PROJECT_DEPLOY_ENABLED == FALSE || $SNOMED_PROJECT_DEPLOY_CONFIG == "" ]]; then
        return
    fi

    IFS='|' read -r -a configArray <<< "$SNOMED_PROJECT_DEPLOY_CONFIG"

    for element in "${configArray[@]}"; do
        IFS=':' read -r -a config <<< "$element"

        if [[ "rundeck" == "${config[0]}" && $GIT_BRANCH == "${config[1]}" ]]; then
            echo "${config[2]}"
            break
        fi
    done
}

# Slacksend can take ";", "," or space separated list of slack channels.
# See:  https://www.jenkins.io/doc/pipeline/steps/slack/
# For consistency use pipe in the CSV, to separate a slack channel list.
getSlackChannel() {
    # Simply replace the pipe with a space and hash.
    echo -n "#${SNOMED_PROJECT_SLACK_CHANNEL//|/ #}"
}

# This string is used to echo the config value back to the pipeline.
STR=""

case $configRequired in
    email)
        STR=$(getEmailList)
        ;;
    rundeck)
        STR=$(getRundeckConfig)
        ;;
    success|failure)
        STR=$(getSlackChannel)
        ;;
    *)
        echo "Unknown config requested: $configRequired"
        exit 1
esac

# If STR is empty echo a # for the pipeline to pickup something.
if [[ -z $STR ]]; then
    echo -n "#"
else
    echo -n "$STR"
fi
