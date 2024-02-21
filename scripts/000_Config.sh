#!/usr/bin/env bash

fixStr() {
    echo "$1" | sed -e 's/^"//' -e 's/"$//' -e 's/""/"/g'
}

BASEFOLDER="/tmp/"
SPREADSHEET_FILE_NAME="${BASEFOLDER}ProjectsDSL.csv"
SPREADSHEET="${SNOMED_SPREADSHEET_URL}/gviz/tq?tqx=out:csv"

if [[ -e $SPREADSHEET_FILE_NAME ]]; then
    echo "Checking age of ${SPREADSHEET_FILE_NAME}"
    FILE_AGE_IN_S=$(( `date +%s` - `stat -L --format %Y ${SPREADSHEET_FILE_NAME}` ))

    if (( FILE_AGE_IN_S > 3600 )); then
        echo "Removing old file ${SPREADSHEET_FILE_NAME}"
        rm $SPREADSHEET_FILE_NAME
    fi
fi

if [[ ! -e $SPREADSHEET_FILE_NAME ]]; then
    echo "Downloading estate spreadsheet from: ${SNOMED_SPREADSHEET_URL}"
    curl --silent --output "${SPREADSHEET_FILE_NAME}" "${SPREADSHEET}" || true
    attemptNumber=0

    while [[ ! -e $SPREADSHEET_FILE_NAME ]]; do
        attemptNumber=$((attemptNumber+1))
        echo "Downloading... ${attemptNumber}"
        sleep 1

        if (( attemptNumber >= 5 )); then
            break
        fi
    done
fi

IFS="/" read -r -a JOBARR <<< "$JOB_NAME"
PROJNAME=${JOBARR[1]}
line=$(grep -i "^\"TRUE\",\"$PROJNAME\"" /tmp/ProjectsDSL.csv | head -1)
IFS="," read -r -a LINEARR <<< "$line"

export SNOMED_PROJECT_ACTIVE=$(fixStr "${LINEARR[0]}")
export SNOMED_PROJECT_NAME=$(fixStr "${LINEARR[1]}")
export SNOMED_PROJECT_GROUP_ARTIFACT=$(fixStr "${LINEARR[2]}")
export SNOMED_PROJECT_BUILD_TOOL=$(fixStr "${LINEARR[3]}")
export SNOMED_PROJECT_LANGUAGE=$(fixStr "${LINEARR[4]}")
export SNOMED_PROJECT_TYPE=$(fixStr "${LINEARR[5]}")
export SNOMED_PROJECT_DEPLOY_ENABLED=$(fixStr "${LINEARR[6]}")
export SNOMED_PROJECT_SLACK_CHANNEL=$(fixStr "${LINEARR[7]}")
export SNOMED_PROJECT_NOTIFIED_USERS=$(fixStr "${LINEARR[8]}")
export SNOMED_PROJECT_USES_BOM=$(fixStr "${LINEARR[9]}")
export SNOMED_PROJECT_DEPENDENCIES=$(fixStr "${LINEARR[10]}")
export SNOMED_PROJECT_OWNER=$(fixStr "${LINEARR[11]}")
export SNOMED_PROJECT_NOTES=$(fixStr "${LINEARR[12]}")
export HOST=$(hostname)

export SNOMED_PROJECT_NAME_ARRAY=( ${SNOMED_PROJECT_NAME//-/ } )
export SNOMED_PROJECT_NICE_NAME="${SNOMED_PROJECT_NAME_ARRAY[@]^}"
