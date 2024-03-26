#!/usr/bin/env bash
LOC=$JENKINS_HOME/userContent
CVE_TSV_FILE=$LOC/cveTable.tsv
URL_BASE=https://jira.ihtsdotools.org/rest/api/2
CVE_URL=https://ossindex.sonatype.org/vulnerability
PROJECT=PIP

findCveTicket() {
    local cve=$1
    read -r -d '' jsonData << EOF
{
  "jql": "project = ${PROJECT} and labels = cve and summary ~ ${cve}"
}
EOF

    curl -s -u "${JIRA_CREDS}" -H "Content-Type: application/json" -X POST \
        --data "${jsonData}" "${URL_BASE}/search" | jq '.total'
}

createNewTicket() {
    local score=$1
    local cve=$2
    local list=$3
    local summary="CVE: Address ${cve} (${score})"
    local listFmt
    listFmt=$(echo "$list" | sed 's/,/|\\n|/g')
    local description="Automatically created CVE ticket:\nMitigate CVE: [${cve}|${CVE_URL}/${cve}]\nSystems affected:\n||System||\n|${listFmt}|\n"
    local issueType="Improvement"
    local label="cve"
    local bigger9
    bigger9=$(echo "$score >= 9.0" | bc)

    if (( bigger9 > 0 )); then
        priority="Critical / High"
    else
        priority="Major / Medium"
    fi

    read -r -d '' jsonData << EOF
{
  "fields": {
    "project": {
      "key": "${PROJECT}"
    },
    "summary": "${summary}",
    "description": "${description}",
    "issuetype": {
      "name": "${issueType}"
    },
    "priority": {
      "name": "${priority}"
    },
    "labels": ["${label}"]
  }
}
EOF

    if [[ $HOST =~ jenkins* ]]; then
        json=$(curl -s -u "${JIRA_CREDS}" -H "Content-Type: application/json" -X POST --data "${jsonData}" "${URL_BASE}/issue")
        echo "$json" | jq '.key'
    else
        echo "WARNING: Jira tickets can only be created from jenkins"
    fi
}

checkAndCreate() {
    local score=$1
    local cve=$2
    local list=$3
    local num
    num=$(findCveTicket "$cve")

    if (( num > 0 )); then
        echo "    Found existing ticket, not creating new one for ${cve} (${score}) (Number of existing tickets = $num)"
    else
        echo "    Found no existing tickets, creating new one for ${cve} (${score})"
        id=$(createNewTicket "${score}" "${cve}" "${list}")
        echo "    Created ticket ${id}"
    fi
}

echo "Checking for new CVE tickets to create using $CVE_TSV_FILE"
HOST=$(hostname)
lastScore="0.0"
lastCve=""
list=""
first=true

while read -r score cve name; do
    if $first; then
        lastScore="$score"
        lastCve="$cve"
        list="$name"
        first=false
        continue
    fi

    if [[ $lastCve == "$cve" ]]; then
        list="$list,$name"
        continue
    fi

    checkAndCreate "$lastScore" "$lastCve" "$list"

    lastScore="$score"
    lastCve="$cve"
    list="$name"
done<"$CVE_TSV_FILE"

if [[ $lastCve != "" ]]; then
    checkAndCreate "$lastScore" "$lastCve" "$list"
fi
