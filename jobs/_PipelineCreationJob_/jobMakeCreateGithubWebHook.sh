#!/usr/bin/env bash
# See: https://docs.github.com/en/rest/repos/webhooks?apiVersion=2022-11-28#create-a-repository-webhook
HOST="https://api.github.com/repos/IHTSDO"
API_VERSION="2022-11-28"
JENKINS_URL="https://dev-jenkins.ihtsdotools.org/multibranch-webhook-trigger/invoke?token="

if (( $# != 3 )); then
    echo "USAGE: $(basename "$0") TOKEN   REPO_NAME   TOKEN"
    exit 1
fi

TOKEN=$1
REPO=$2
ID=$3

getHook() {
    REPO=$1

    json=$(curl -s -L \
            -H "Accept: application/vnd.github+json" \
            -H "Authorization: Bearer ${TOKEN}" \
            -H "X-GitHub-Api-Version: ${API_VERSION}" \
            "${HOST}/${REPO}/hooks"
          )
    echo "$json" | jq '.[].config.url' | grep "dev-jenkins" | sed -e 's/^"//' -e 's/"$//'
}

makeHook() {
    REPO=$1
    ID=$2
    URL="${JENKINS_URL}${ID}"

    json=$(curl -s -L \
            -X POST \
            -H "Accept: application/vnd.github+json" \
            -H "Authorization: Bearer ${TOKEN}" \
            -H "X-GitHub-Api-Version: ${API_VERSION}" \
            "${HOST}/${REPO}/hooks" \
            -d "{\"name\":\"web\",\"active\":true,\"events\":[\"push\"],\"config\":{\"url\":\"${URL}\",\"content_type\":\"application/x-www-form-urlencoded\",\"insecure_ssl\":\"0\"}}"
          )

    echo "$json" | jq
}

hook=$(getHook "$REPO")

if [[ -z $hook ]]; then
    makeHook "$REPO" "${ID}"
else
    echo "{ \"message\": \"Hook already exists\", \"repo\" : \"$REPO\", \"id\" : \"$hook\" }" | jq
fi
