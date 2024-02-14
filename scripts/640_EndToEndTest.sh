#!/usr/bin/env bash
source "$SCRIPTS_PATH/000_Config.sh"
figlet -w 500 "E2E Tests"

if [[ -d cypress ]]; then
    # Make a config file for Cypress.
    JSON_FILE="cypress.env.json"

    {
        echo "{"

        while read -r key value; do
            echo "    \"$key\": \"$value\","
        done <<< "$(set | grep "^TEST_" | sed -e 's/=/\t/' -e "s/\t'/\t/" -e "s/'$//" | cut -f 1,2)"

        case $GIT_BRANCH in
            main | master)
                echo "    \"URL_LOGIN\": \"https://uat-ims.ihtsdotools.org/#/login?serviceReferer=\","
                echo "    \"URL_BROWSER\": \"https://uat-browser.ihtsdotools.org\","
                echo "    \"URL_AUTHORING\": \"https://uat-authoring.ihtsdotools.org\","
                echo "    \"URL_REPORTING\": \"https://uat-snowstorm.ihtsdotools.org/reporting/\","
                echo "    \"URL_RAD\": \"https://uat-release.ihtsdotools.org/\","
                echo "    \"URL_SIMPLEX\": \"https://uat-simplex.ihtsdotools.org/\""
                ;;
            *)
                echo "    \"URL_LOGIN\": \"https://dev-ims.ihtsdotools.org/#/login?serviceReferer=\","
                echo "    \"URL_BROWSER\": \"https://dev-browser.ihtsdotools.org\","
                echo "    \"URL_AUTHORING\": \"https://dev-authoring.ihtsdotools.org\","
                echo "    \"URL_REPORTING\": \"https://dev-snowstorm.ihtsdotools.org/reporting/\","
                echo "    \"URL_RAD\": \"https://dev-release.ihtsdotools.org/\","
                echo "    \"URL_SIMPLEX\": \"https://dev-simplex.ihtsdotools.org/\""
                ;;
        esac

        echo "}"
    } > "$JSON_FILE"

    # Run Cypress.
    npx cypress run
fi
