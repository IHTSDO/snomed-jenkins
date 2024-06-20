#!/usr/bin/env bash
# See: https://docs.github.com/en/rest/repos/webhooks?apiVersion=2022-11-28#create-a-repository-webhook
GIT_URL="https://api.github.com/repos/IHTSDO"
API_VERSION="2022-11-28"
API_KEY=${GIT_WEB_HOOK_CREATE_TOKEN}
JENKINS_URL="https://jenkins.${SNOMED_TOOLS_URL}/multibranch-webhook-trigger/invoke?token="

echo "SNOMED_TOOLS_URL = $SNOMED_TOOLS_URL"

getHook() {
    REPO=$1

    json=$(curl -s -L \
            -H "Accept: application/vnd.github+json" \
            -H "Authorization: Bearer ${API_KEY}" \
            -H "X-GitHub-Api-Version: ${API_VERSION}" \
            "${GIT_URL}/${REPO}/hooks"
          )

    echo "$json" | jq -r 'map([.id, .config.url] | join(", ")) | join("\n")' | grep "jenkins"
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
            "${GIT_URL}/${REPO}/hooks" \
            -d "{\"name\":\"web\",\"active\":true,\"events\":[\"push\"],\"config\":{\"url\":\"${URL}\",\"content_type\":\"application/x-www-form-urlencoded\",\"insecure_ssl\":\"0\"}}"
          )

    echo "$json" | jq
}

replaceHook() {
    REPO=$1
    TOKEN=$2
    ID=$3
    URL="${JENKINS_URL}${TOKEN}"

    json=$(curl -s -L \
            -X PATCH \
            -H "Accept: application/vnd.github+json" \
            -H "Authorization: Bearer ${API_KEY}" \
            -H "X-GitHub-Api-Version: ${API_VERSION}" \
            "${GIT_URL}/${REPO}/hooks/${ID}" \
            -d "{\"name\":\"web\",\"active\":true,\"events\":[\"push\"],\"config\":{\"url\":\"${URL}\",\"content_type\":\"application/x-www-form-urlencoded\",\"insecure_ssl\":\"0\"}}"
          )

    echo "$json" | jq
}

HOST=$(hostname)

if [[ $HOST =~ prod-jenkins* ]]; then
    echo "Creating web hooks on github"

    while read -r TOKEN REPO; do
        echo "    ----- ${REPO} -----"
        hook=$(getHook "$REPO")

        if [[ -z $hook ]]; then
            makeHook "$REPO" "${TOKEN}"
        else
            id="${hook//,*/}"
            url="${hook//*, /}"

            if [[ $hook =~ dev-jenkins ]]; then
                replaceHook "$REPO" "${TOKEN}" "${id}"
            else
                echo "{ \"message\": \"Hook already exists\", \"repo\" : \"$REPO\", \"id\" : \"$id\", \"url\" : \"$url\" }" | jq
            fi
        fi
    done<"${HOME}/hook_list.txt"
else
    echo "NOT Creating web hooks on github"
fi
