#!/usr/bin/env bash
source "$SCRIPTS_PATH/000_Config.sh"
figlet -w 500 "Trigger Downstream Builds"

buildDependency() {
    DEPTOBUILD=$1

    if [[ -z "$CRUMB" ]]; then
        echo "Logging in to ${URL}"
        CRUMB=$(curl -s --cookie-jar "${COOKIE_FILE}" -u "${BUILD_TRIGGER_USR}:${BUILD_TRIGGER_PSW}" "https://${URL}/crumbIssuer/api/json" | jq -r '.crumb')
        TOKEN_VALUE=$(curl -s -X POST --cookie "${COOKIE_FILE}" "https://${URL}/me/descriptorByName/jenkins.security.ApiTokenProperty/generateNewToken?newTokenName=${TOKEN_NAME}" -H "Jenkins-Crumb:${CRUMB}" -u "${BUILD_TRIGGER_USR}:${BUILD_TRIGGER_PSW}" | jq -r '.data.tokenValue')
        echo "Checking for dependencies of ${SNOMED_PROJECT_NAME}"
    fi

    echo -n "    Building dependency: ${DEPTOBUILD} = "
    status=$(curl -s -X POST --write-out '%{http_code}\n' --USER "${BUILD_TRIGGER_USR}:${TOKEN_VALUE}" "https://${URL}/job/jobs/job/${DEPTOBUILD}/job/${GIT_BRANCH}/build?delay=${DELAY}" 2>&1 | head -1)

    if [[ "$status" == "201" ]]; then
        echo "${GIT_BRANCH} Running"
    else
        if [[ "$GIT_BRANCH" == "main" ]]; then
            GIT_BRANCH="master"
            status=$(curl -s -X POST --write-out '%{http_code}\n' --USER "${BUILD_TRIGGER_USR}:${TOKEN_VALUE}" "https://${URL}/job/jobs/job/${DEPTOBUILD}/job/master/build?delay=${DELAY}" 2>&1 | head -1)
        elif [[ "$GIT_BRANCH" == "master" ]]; then
            GIT_BRANCH="main"
            status=$(curl -s -X POST --write-out '%{http_code}\n' --USER "${BUILD_TRIGGER_USR}:${TOKEN_VALUE}" "https://${URL}/job/jobs/job/${DEPTOBUILD}/job/main/build?delay=${DELAY}" 2>&1 | head -1)
        fi

        if [[ "$status" == "201" ]]; then
            echo "${GIT_BRANCH} Running"
        else
            echo "${GIT_BRANCH} Branch not found"
        fi
    fi
}

COOKIE_FILE=/tmp/trigger_cookie.txt
CRUMB=""
URL=jenkins.ihtsdotools.org
DELAY="0sec"
TOKEN_NAME="${SNOMED_PROJECT_NAME}-${GIT_BRANCH}"

while IFS="," read -r -a LINEARR; do
    # get required columns from spreadsheet, removing quotes.
    PRJ="${LINEARR[1]//\"/}"
    DEPS="${LINEARR[10]//\"/}"

    # Convert list of dependencies into array and iterate over it.
    IFS="|" read -r -a DEPARR <<< "${DEPS}"

    for DEP in "${DEPARR[@]}"; do
        DEP_PRJ="$(echo "${DEP}" | cut -d':' -f2)"

        # If is dependency of this project then build it!
        if [[ "$SNOMED_PROJECT_NAME" == "$DEP_PRJ" ]] && [[ "$SNOMED_PROJECT_NAME" != "$PRJ" ]]; then
            if $DOWNSTREAM_ENABLED; then
                buildDependency "${PRJ}"
            else
                echo "Not building ${PRJ}"
            fi
        fi
    done
done < "${SPREADSHEET_FILE_NAME}"
