#!/usr/bin/env bash
# See: https://docs.github.com/en/rest/repos/webhooks?apiVersion=2022-11-28#create-a-repository-webhook
HOST="https://api.github.com/repos/IHTSDO"
API_VERSION="2022-11-28"
API_KEY=${GIT_WEB_HOOK_CREATE_TOKEN}
JENKINS_URL="https://dev-jenkins.ihtsdotools.org/multibranch-webhook-trigger/invoke?token="

getHook() {
    REPO=$1

    json=$(curl -s -L \
            -H "Accept: application/vnd.github+json" \
            -H "Authorization: Bearer ${API_KEY}" \
            -H "X-GitHub-Api-Version: ${API_VERSION}" \
            "${HOST}/${REPO}/hooks"
          )
    echo "$json" | jq '.[].config.url' | grep "dev-jenkins" | sed -e 's/^"//' -e 's/"$//'
}

makeHook() {
    REPO=$1
    TOKEN=$2
    URL="${JENKINS_URL}${TOKEN}"

    json=$(curl -s -L \
            -X POST \
            -H "Accept: application/vnd.github+json" \
            -H "Authorization: Bearer ${API_KEY}" \
            -H "X-GitHub-Api-Version: ${API_VERSION}" \
            "${HOST}/${REPO}/hooks" \
            -d "{\"name\":\"web\",\"active\":true,\"events\":[\"push\"],\"config\":{\"url\":\"${URL}\",\"content_type\":\"application/x-www-form-urlencoded\",\"insecure_ssl\":\"0\"}}"
          )

    echo "$json" | jq
}

while read -r TOKEN REPO; do
    hook=$(getHook "$REPO")

    if [[ -z $hook ]]; then
        makeHook "$REPO" "${TOKEN}"
    else
        echo "{ \"message\": \"Hook already exists\", \"repo\" : \"$REPO\", \"id\" : \"$hook\" }" | jq
    fi
done<"${HOME}/hook_list.txt"
