#!/usr/bin/env bash
source ../_PipelineCreationJob_/000_Config.sh
figlet -w 500 "${STAGE_NAME}"

if [[ $SNOMED_PROJECT_LANGUAGE == "Cypress" ]]; then
    # Make a config file for Cypress.
    JSON_FILE="cypress.env.json"

    {
        echo "{"
        first=true

        while read -r key value; do
            if $first; then
                first=false
            else
                echo ","
            fi

            echo -n "    \"$key\": \"$value\""
        done<<<"$(set | grep "^TEST_" | sed -e 's/=/\t/' -e "s/\t'/\t/" -e "s/'$//" | cut -f 1,2)"

        echo
        echo "}"
    } > "$JSON_FILE"

    # Run Cypress.
    npx cypress run
fi
