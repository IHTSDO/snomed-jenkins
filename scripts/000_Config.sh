#!/usr/bin/env bash
# Requires 2 environment variables are set:
# SNOMED_SPREADSHEET_URL and JOB_NAME
# where job_name is of the format 'folder/name'

fixStr() {
    echo "$1" | sed -e 's/^"//' -e 's/"$//' -e 's/""/"/g'
}

if [[ -z "$JOB_NAME" ]]; then
    echo "JOB_NAME not set, must be of the form 'folder/name'"
    exit 1
fi

if [[ -z "$SNOMED_SPREADSHEET_URL" ]]; then
    echo "SNOMED_SPREADSHEET_URL must point to the URL of the master spreadsheet"
    exit 1
fi

BASEFOLDER="/tmp/"
SPREADSHEET="${SNOMED_SPREADSHEET_URL}/gviz/tq?tqx=out:csv"
MAXIMUM_AGE_OF_FILE_IN_SECONDS_BEFORE_DOWNLOADING_AGAIN=3600
export SPREADSHEET_FILE_NAME="${BASEFOLDER}ProjectsDSL.csv"

if [[ -e $SPREADSHEET_FILE_NAME ]]; then
    echo "Checking age of ${SPREADSHEET_FILE_NAME}"
    FILE_AGE_IN_SECONDS=$(( $(date +%s) - $(stat -L --format %Y ${SPREADSHEET_FILE_NAME}) ))

    if (( FILE_AGE_IN_SECONDS > MAXIMUM_AGE_OF_FILE_IN_SECONDS_BEFORE_DOWNLOADING_AGAIN )); then
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

# From spreadsheet get the row for project and convert each column to a variable.
IFS="/" read -r -a JOBARR <<< "$JOB_NAME"
PROJNAME=${JOBARR[1]}
line=$(grep -i -E "^\"(TRUE|FALSE)\",\"$PROJNAME\"" "${SPREADSHEET_FILE_NAME}" | head -1)
IFS="," read -r -a LINEARR <<< "$line"

SNOMED_PROJECT_ACTIVE=$(fixStr "${LINEARR[0]}")
SNOMED_PROJECT_NAME=$(fixStr "${LINEARR[1]}")
SNOMED_PROJECT_GROUP_ARTIFACT=$(fixStr "${LINEARR[2]}")
SNOMED_PROJECT_BUILD_TOOL=$(fixStr "${LINEARR[3]}")
SNOMED_PROJECT_LANGUAGE=$(fixStr "${LINEARR[4]}")
SNOMED_PROJECT_TYPE=$(fixStr "${LINEARR[5]}")
SNOMED_PROJECT_DEPLOY_ENABLED=$(fixStr "${LINEARR[6]}")
SNOMED_PROJECT_SLACK_CHANNEL=$(fixStr "${LINEARR[7]}")
SNOMED_PROJECT_NOTIFIED_USERS=$(fixStr "${LINEARR[8]}")
SNOMED_PROJECT_USES_BOM=$(fixStr "${LINEARR[9]}")
SNOMED_PROJECT_DEPENDENCIES=$(fixStr "${LINEARR[10]}")
SNOMED_PROJECT_OWNER=$(fixStr "${LINEARR[11]}")
SNOMED_PROJECT_NOTES=$(fixStr "${LINEARR[12]}")
# Generate array of project name words
IFS='-' read -r -a SNOMED_PROJECT_NAME_ARRAY <<< "$SNOMED_PROJECT_NAME"
# Make nice printable project name, capatilizing first letter of each word.
SNOMED_PROJECT_NICE_NAME="${SNOMED_PROJECT_NAME_ARRAY[*]^}"
HOST=$(hostname)

export SNOMED_PROJECT_ACTIVE
export SNOMED_PROJECT_NAME
export SNOMED_PROJECT_GROUP_ARTIFACT
export SNOMED_PROJECT_BUILD_TOOL
export SNOMED_PROJECT_LANGUAGE
export SNOMED_PROJECT_TYPE
export SNOMED_PROJECT_DEPLOY_ENABLED
export SNOMED_PROJECT_SLACK_CHANNEL
export SNOMED_PROJECT_NOTIFIED_USERS
export SNOMED_PROJECT_USES_BOM
export SNOMED_PROJECT_DEPENDENCIES
export SNOMED_PROJECT_OWNER
export SNOMED_PROJECT_NOTES
export SNOMED_PROJECT_NAME_ARRAY
export SNOMED_PROJECT_NICE_NAME
export HOST
