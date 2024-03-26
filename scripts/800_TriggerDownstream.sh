#!/usr/bin/env bash
source "$SCRIPTS_PATH/000_Config.sh"
figlet -w 500 "Trigger Downstream Builds"

loginToJenkins() {
    if $DOWNSTREAM_ENABLED; then
        echo "${INDENT}Logging in to ${JENKINS_URL}"
        CRUMB=$(curl -s --cookie-jar "${COOKIE_FILE}" -u "${BUILD_TRIGGER_USR}:${BUILD_TRIGGER_PSW}" "${JENKINS_URL}crumbIssuer/api/json" | jq -r '.crumb')
        TOKEN_VALUE=$(curl -s -X POST --cookie "${COOKIE_FILE}" "${JENKINS_URL}me/descriptorByName/jenkins.security.ApiTokenProperty/generateNewToken?newTokenName=${TOKEN_NAME}" -H "Jenkins-Crumb:${CRUMB}" -u "${BUILD_TRIGGER_USR}:${BUILD_TRIGGER_PSW}" | jq -r '.data.tokenValue')
        echo "${INDENT}Checking for dependencies of ${SNOMED_PROJECT_NAME}"
    fi
}

buildDependency() {
    DEPTOBUILD=$1
    local INDENT
    INDENT=$(yes X | head -"${DEPTH}"  | xargs | sed -e 's/X/   /g')
    local DELAY=$(( DEPTH * 2 * 60 ))

    echo -n "${INDENT}-> ${PRJ} : "

    if ! $DOWNSTREAM_ENABLED; then
        echo "Would have been built"
        return
    fi

    local url="${JENKINS_URL}job/jobs/job/${DEPTOBUILD}/job/${GIT_BRANCH}/build?delay=${DELAY}sec&DOWNSTREAM_ENABLED=false"
    status=$(curl -s -X POST --write-out '%{http_code}\n' --USER "${BUILD_TRIGGER_USR}:${TOKEN_VALUE}" "${url}" 2>&1 | head -1)

    if [[ "$status" == "201" ]]; then
        echo "${GIT_BRANCH} build started"
    else
        if [[ "$GIT_BRANCH" == "main" ]]; then
            GIT_BRANCH="master"
            status=$(curl -s -X POST --write-out '%{http_code}\n' --USER "${BUILD_TRIGGER_USR}:${TOKEN_VALUE}" "${JENKINS_URL}job/jobs/job/${DEPTOBUILD}/job/master/build?delay=${DELAY}sec&DOWNSTREAM_ENABLED=false" 2>&1 | head -1)
        elif [[ "$GIT_BRANCH" == "master" ]]; then
            GIT_BRANCH="main"
            status=$(curl -s -X POST --write-out '%{http_code}\n' --USER "${BUILD_TRIGGER_USR}:${TOKEN_VALUE}" "${JENKINS_URL}job/jobs/job/${DEPTOBUILD}/job/main/build?delay=${DELAY}sec&DOWNSTREAM_ENABLED=false" 2>&1 | head -1)
        fi

        if [[ "$status" == "201" ]]; then
            echo "${GIT_BRANCH} build started"
        else
            echo "${GIT_BRANCH} Branch not found"
        fi
    fi
}

startToBuildDependencies() {
    local CURPRJ=$1
    DEPTH=$(( DEPTH + 1 ))
    local INDENT
    INDENT=$(yes X | head -${DEPTH}  | xargs | sed -e 's/X/   /g')
    PROJECTS_SEEN[$CURPRJ]="1"

    while IFS="," read -r -a LINEARR; do
        # get required columns from spreadsheet, removing quotes.
        local PRJ="${LINEARR[1]//\"/}"
        local DEPS="${LINEARR[10]//\"/}"

        # Convert list of dependencies into array and iterate over it.
        IFS="|" read -r -a DEPARR <<< "${DEPS}"

        for DEP in "${DEPARR[@]}"; do
            local DEP_PRJ="$(echo "${DEP}" | cut -d':' -f2)"

            # If is dependency of this project then build it!
            if [[ "$CURPRJ" == "$DEP_PRJ" ]] && [[ "$CURPRJ" != "$PRJ" ]]; then
                if [[ -z "${PROJECTS_SEEN[${PRJ}]}" ]]; then
                    buildDependency "${PRJ}"
                    startToBuildDependencies "${PRJ}"
                else
                    echo "${INDENT}-> ! ${PRJ} : Is already building so skipping"
                fi
            fi
        done
    done < "${SPREADSHEET_FILE_NAME}"
    DEPTH=$(( DEPTH - 1 ))
}

COOKIE_FILE=/tmp/trigger_cookie.txt
CRUMB=""
TOKEN_NAME="${SNOMED_PROJECT_NAME}-${GIT_BRANCH}"
DEPTH=0

declare -A PROJECTS_SEEN=()
PROJECTS_SEEN[$SNOMED_PROJECT_NAME]="1"

echo "${SNOMED_PROJECT_NAME}"
loginToJenkins
startToBuildDependencies "${SNOMED_PROJECT_NAME}"
