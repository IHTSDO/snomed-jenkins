#!/usr/bin/env bash
source "$SCRIPTS_PATH/000_Config.sh"
figlet -w 500 "Trigger Downstream Builds"

buildDependency() {
    DEPTOBUILD=$1

    if [[ -z $CRUMB ]]; then
        echo "    Logging in to ${URL}"
        CRUMB=$(curl -s --cookie-jar /tmp/cookies -u "${USERNAME}:${API_TOKEN}" "https://${URL}/crumbIssuer/api/json" | jq -r '.crumb')
        TOKEN_VALUE=$(curl -s -X POST --cookie /tmp/cookies "https://${URL}/me/descriptorByName/jenkins.security.ApiTokenProperty/generateNewToken?newTokenName=${TOKEN_NAME}" -H "Jenkins-Crumb:${CRUMB}" -u "${USERNAME}:${API_TOKEN}" | jq -r '.data.tokenValue')
    fi

    echo -n "    ${DEPTOBUILD}: "
#    echo curl -s -X POST --write-out '%{http_code}\n' --USER ${USERNAME}:"${TOKEN_VALUE}" "https://${URL}/job/jobs/job/${DEPTOBUILD}/job/${GIT_BRANCH}/build?delay=${DELAY}"
    echo "    ${DEPTOBUILD} -> ${GIT_BRANCH}"
}

set
exit 1

CRUMB=""
URL=jenkins.ihtsdotools.org
DELAY="60sec"
TOKEN_NAME="${SNOMED_PROJECT_NAME}-${GIT_BRANCH}"
echo "Checking for dependencies of ${SNOMED_PROJECT_NAME}"

while IFS="," read -r -a LINEARR; do
    # get required columns from spreadsheet, removing quotes.
    PRJ="${LINEARR[1]//\"/}"
    DEPS="${LINEARR[10]//\"/}"

    # Convert list of dependencies into array and iterate over it.
    IFS="|" read -r -a DEPARR <<< "${DEPS}"

    for DEP in "${DEPARR[@]}"; do
        DEP_PRJ="$(echo "${DEP}" | cut -d':' -f2)"

        # If is dependency of this project then build it!
        if [[ "$DEP_PRJ" == "$SNOMED_PROJECT_NAME" ]]; then
            buildDependency "${PRJ}"
        fi
    done
done < "${SPREADSHEET_FILE_NAME}"
