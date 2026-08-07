#!/usr/bin/env bash

# Jenkins
LOC=$JENKINS_HOME/userContent
CVE_TSV_FILE=$LOC/cveTable.tsv
COMPONENT_CACHE=/tmp/jira_components_cache.tsv
CVE_URL=https://ossindex.sonatype.org/vulnerability

# Jira
URL_BASE=https://snomed.atlassian.net
VIEW_URL=$URL_BASE/browse/
SEARCH_URL=$URL_BASE/rest/api/3/search/jql

echo "SNOMED_TOOLS_URL = $SNOMED_TOOLS_URL"
declare -A componentMap

ownerToProject() {
    case "${1,,}" in
        wci)      echo "RT2"  ;;
        telliant) echo "MLDS" ;;
        *)        echo "PIP"  ;;
    esac
}

# API Documentation: https://docs.atlassian.com/software/jira/docs/api/REST/8.20.8/#project-getProjectComponents
getListAllComponents() {
    if [[ -e "${COMPONENT_CACHE}" ]]; then
        echo "Components cache file already exists, skipping."
        return
    fi

    echo "Creating components file."

    # Make API request and store response
    local response=$(curl -s -u "$JIRA_API_KEY" \
        -H "Accept: application/json" \
        -H "Content-Type: application/json" \
        -X GET "${URL_BASE}/rest/api/3/project/PIP/components")

    echo "$response" | jq -r '.[] | [.id, .name] | @tsv' > "${COMPONENT_CACHE}"
}

loadComponentsIntoMap() {
    echo "Loading all components into map"

    while IFS=$'\t' read -r componentId componentName; do
        componentMap["$componentName"]="$componentId"
    done < "${COMPONENT_CACHE}"
}

# API Documentation: https://docs.atlassian.com/software/jira/docs/api/REST/8.20.8/#search
findCveTicket() {
    local cve=$1
    local project=$2
    local jql jsonData json num

    jql="project = ${project} and labels = cve and summary ~ ${cve}"
    jsonData=$(jq -n --arg jql "$jql" '{ jql: $jql }')
    json=$(curl -s -u "$JIRA_API_KEY" \
         -H "Accept: application/json" \
         -H "Content-Type: application/json" \
         -X POST \
         --data "$jsonData" \
         "$SEARCH_URL")
    num=$(echo "$json" | jq '.issues | length')

    if (( num == 0 )) && [[ "$project" != "PIP" ]]; then
        jql="project = PIP and labels = cve and summary ~ ${cve}"
        jsonData=$(jq -n --arg jql "$jql" '{ jql: $jql }')
        json=$(curl -s -u "$JIRA_API_KEY" \
             -H "Accept: application/json" \
             -H "Content-Type: application/json" \
             -X POST \
             --data "$jsonData" \
             "$SEARCH_URL")
        num=$(echo "$json" | jq '.issues | length')
    fi

    echo "$num"
}

convertComponentListNamesToIDs() {
    list=$1
    IFS=',' read -ra COMPONENT_NAMES <<< "$list"
    local first=true
    
    for componentName in "${COMPONENT_NAMES[@]}"; do
        if [[ -v componentMap["$componentName"] ]]; then
            if $first; then
                first=false
            else
                echo -n ","
            fi

            echo -n "{\"id\": \"${componentMap[$componentName]}\"}"
        fi
    done
}

# API Documentation: https://docs.atlassian.com/software/jira/docs/api/REST/8.20.8/#issue-createIssue
createNewTicket() {
    local score=$1
    local cve=$2
    local list=$3
    local project=$4
    local summary="CVE: Address ${cve} (${score})"

    local bigger95 bigger80
    bigger95=$(echo "$score >= 9.5" | bc)
    bigger80=$(echo "$score >= 8.0" | bc)

    if ((bigger95 > 0)); then
        priority="Blocker / Highest"
    elif ((bigger80 > 0)); then
        priority="Critical / High"
    else
        priority="Major / Medium"
    fi

    local systemsList
    systemsList=$(echo "$list" | sed 's/,/, /g')

    local jsonData
    jsonData=$(jq -n \
        --arg project "$project" \
        --arg summary "$summary" \
        --arg issueType "Improvement" \
        --arg priority "$priority" \
        --arg cve "$cve" \
        --arg systemsList "$systemsList" \
        '{
            fields: {
                project: { key: $project },
                summary: $summary,
                issuetype: { name: $issueType },
                priority: { name: $priority },
                labels: ["cve"],
                description: {
                    type: "doc",
                    version: 1,
                    content: [
                        { type: "paragraph", content: [{ type: "text", text: "Automatically created CVE ticket." }] },
                        { type: "paragraph", content: [{ type: "text", text: ("Mitigate CVE: " + $cve) }] },
                        { type: "paragraph", content: [{ type: "text", text: ("Systems affected: " + $systemsList) }] }
                    ]
                }
            }
        }'
    )

    if [[ $HOST =~ prod-jenkins* ]]; then
            local response
            response=$(echo "$jsonData" | curl -s -u "$JIRA_API_KEY" \
                -H "Accept: application/json" \
                -H "Content-Type: application/json" \
                -X POST \
                --data @- \
                "${URL_BASE}/rest/api/3/issue")

            echo "$response"
            echo "$response" | jq -r '.key'
        else
            echo "WARNING: Jira tickets can only be created from Jenkins"
        fi
}

checkAndCreate() {
    local score=$1
    local cve=$2
    local list=$3
    local project=$4
    local num
    num=$(findCveTicket "$cve" "$project")

    if ((num > 0)); then
        echo "    Found existing ticket, not creating new one for ${cve} (${score}) in ${project} (Number of existing tickets = $num): $list"
    else
        echo "    Found no existing tickets, creating new one for ${cve} (${score}) in ${project}: $list)"
        id=$(createNewTicket "${score}" "${cve}" "${list}" "${project}")
        echo "    Created ticket ${id}"
    fi
}

getListAllComponents
loadComponentsIntoMap

echo "Checking for new CVE tickets to create using $CVE_TSV_FILE"
HOST=$(hostname)

declare -A ticketScores   # "cve|project" -> highest score
declare -A ticketNames    # "cve|project" -> comma-separated component list

while IFS=$'\t' read -r score cve name owner; do
    project=$(ownerToProject "$owner")
    key="${cve}|${project}"

    if [[ -z "${ticketNames[$key]+x}" ]]; then
        ticketScores[$key]="$score"
        ticketNames[$key]="$name"
    else
        ticketNames[$key]="${ticketNames[$key]},$name"
        higher=$(echo "$score > ${ticketScores[$key]}" | bc)
        if (( higher > 0 )); then
            ticketScores[$key]="$score"
        fi
    fi
done < "$CVE_TSV_FILE"

for key in "${!ticketNames[@]}"; do
    IFS='|' read -r cve project <<< "$key"
    checkAndCreate "${ticketScores[$key]}" "$cve" "${ticketNames[$key]}" "$project"
done
