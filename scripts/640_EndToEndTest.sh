#!/usr/bin/env bash
source "$SCRIPTS_PATH/000_Config.sh"
figlet -w 500 "E2E Tests"

if [[ -d cypress ]]; then
    # Make a config file for Cypress.
    JSON_FILE="cypress.env.json"

    {
        echo "{"
        # set | grep "JOB_NAME"

        # Populate cypress config file with any TEST_* variables,
        # see https://JENKINS_URL/manage/configure "Global properties" section (You need jenkins admin permission to see/edit these).
        while read -r key value; do
            echo "    \"$key\": \"$value\","
        done <<< "$(set | grep "^TEST_" | sed -e 's/=/\t/' -e "s/\t'/\t/" -e "s/'$//" | cut -f 1,2)"

        # Populate config file with URLS depending on job name.
        if [[ ${JOB_NAME} =~ ^e2euat.*$ ]]; then
            echo "    \"URL_LOGIN\": \"https://uat-ims.${SNOMED_TOOLS_URL}/#/login?serviceReferer=\","
            echo "    \"URL_BROWSER\": \"https://uat-browser.${SNOMED_TOOLS_URL}\","
            echo "    \"URL_AUTHORING\": \"https://uat-authoring.${SNOMED_TOOLS_URL}\","
            echo "    \"URL_REPORTING\": \"https://uat-snowstorm.${SNOMED_TOOLS_URL}/reporting/\","
            echo "    \"URL_RAD\": \"https://uat-release.${SNOMED_TOOLS_URL}/\","
            echo "    \"URL_SIMPLEX\": \"https://uat-simplex.${SNOMED_TOOLS_URL}/\""

        elif [[ ${JOB_NAME} =~ ^e2eprod.*$ ]]; then
            echo "    \"URL_LOGIN\": \"https://prod-ims.${SNOMED_TOOLS_URL}/#/login?serviceReferer=\","
            echo "    \"URL_BROWSER\": \"https://prod-browser.${SNOMED_TOOLS_URL}\","
            echo "    \"URL_AUTHORING\": \"https://prod-authoring.${SNOMED_TOOLS_URL}\","
            echo "    \"URL_REPORTING\": \"https://prod-snowstorm.${SNOMED_TOOLS_URL}/reporting/\","
            echo "    \"URL_RAD\": \"https://prod-release.${SNOMED_TOOLS_URL}/\","
            echo "    \"URL_SIMPLEX\": \"https://prod-simplex.${SNOMED_TOOLS_URL}/\""

        else
            echo "    \"URL_LOGIN\": \"https://dev-ims.${SNOMED_TOOLS_URL}/#/login?serviceReferer=\","
            echo "    \"URL_BROWSER\": \"https://dev-browser.${SNOMED_TOOLS_URL}\","
            echo "    \"URL_AUTHORING\": \"https://dev-authoring.${SNOMED_TOOLS_URL}\","
            echo "    \"URL_REPORTING\": \"https://dev-snowstorm.${SNOMED_TOOLS_URL}/reporting/\","
            echo "    \"URL_RAD\": \"https://dev-release.${SNOMED_TOOLS_URL}/\","
            echo "    \"URL_SIMPLEX\": \"https://dev-simplex.${SNOMED_TOOLS_URL}/\""
        fi

        echo "}"
    } > "$JSON_FILE"

    # Run Cypress.
    npx cypress run
fi
