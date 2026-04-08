#!/usr/bin/env bash

# Jenkins
LOC=$JENKINS_HOME/userContent
CVE_TSV_FILE=$LOC/cveTable.tsv
CVE_HTML_FILE=$LOC/cveTable.html
CVE_URL=https://ossindex.sonatype.org/vulnerability
BUILD_URL=$JENKINS_URL/job/cve/job

# Jira
URL_BASE=https://snomed.atlassian.net
VIEW_URL=$URL_BASE/browse/
SEARCH_URL=$URL_BASE/rest/api/3/search/jql

fixStr() {
    echo "$1" | sed -e 's/\r//' -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//' \
                    -e 's/^"//' -e 's/"$//' \
                    -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//' \
                    -e 's/""/"/g'
}

# Builds the projectOwners associative array: projectName -> owner.
# Expects the spreadsheet CSV file path as $1.
loadOwnerMap() {
    local spreadsheetFile="${1:-${SPREADSHEET_FILE_NAME:-/tmp/ProjectsDSL.csv}}"

    if [[ ! -e "$spreadsheetFile" ]]; then
        echo "WARNING: Spreadsheet file not found: $spreadsheetFile, owner data unavailable"
        return
    fi

    echo "Loading owner map from $spreadsheetFile"

    # Skip header row. Columns: [0]=enabled [1]=project name ... [12]=owner
    local firstLine=true
    while IFS=',' read -r -a cols || [[ "${#cols[@]}" -gt 0 ]]; do
        if $firstLine; then
            firstLine=false
            continue
        fi
        local projectName
        projectName=$(fixStr "${cols[1]}" | tr '[:upper:]' '[:lower:]')
        local owner
        owner=$(fixStr "${cols[12]}")
        if [[ -n "$projectName" ]]; then
            projectOwners["$projectName"]="${owner:-Unknown}"
            echo "    owner map: '$projectName' -> '${owner:-Unknown}'"
        fi
    done < "$spreadsheetFile"
}

findCveTickets() {
    local cve=$1
    local jql="summary ~ \"${cve}\" OR description ~ \"${cve}\" OR comment ~ \"${cve}\""
    local jsonData=$(jq -n --arg jql "$jql" '{ jql: $jql, "fields": ["id","key","summary","status","assignee","priority"] }')
    local json=$(curl -s -u "$JIRA_API_KEY" \
         -H "Accept: application/json" \
         -H "Content-Type: application/json" \
         -X POST \
         --data "$jsonData" \
         "$SEARCH_URL")

    local num=$(echo "$json" | jq '.issues | length')

    if (( num > 0 )); then
        echo "$json" | jq -r '.issues[] | "\(.key)\t\(.fields.status.name)\t\(.fields.summary)\t\(.fields.assignee.displayName)\t\(.fields.priority.name)"'
    else
        echo "No JIRA tickets found"
    fi
}

writeHtmlHeader() {
    cat<<EOF
<!DOCTYPE html>
<html>

<head>
    <title>CVE</title>
    <style>
        html * {
            font-size: 14px;
            font-family: Arial, sans-serif;
        }

        table.blueTable {
            border: 1px solid #1C6EA4;
            background-color: #EEEEEE;
            width: 100%;
            text-align: left;
            border-collapse: collapse;
        }

        table.blueTableSummary {
            border: 1px solid #1C6EA4;
            background-color: #EEEEEE;
            text-align: left;
            border-collapse: collapse;
        }

        table.blueTable td,
        table.blueTable th {
            border: 1px solid #AAAAAA;
            padding: 3px 2px;
        }

        table.blueTable tbody td {
            font-size: 13px;
            text-align: center;
        }

        table.blueTable tr:nth-child(even) {
            background: #D0E4F5;
        }

        table.blueTable thead {
            background: #1C6EA4;
            background: -moz-linear-gradient(top, #5592bb 0%, #327cad 66%, #1C6EA4 100%);
            background: -webkit-linear-gradient(top, #5592bb 0%, #327cad 66%, #1C6EA4 100%);
            background: linear-gradient(to bottom, #5592bb 0%, #327cad 66%, #1C6EA4 100%);
            border-bottom: 2px solid #444444;
        }

        table.blueTable thead th {
            font-size: 15px;
            font-weight: bold;
            text-align: center;
            color: #FFFFFF;
            border-left: 2px solid #D0E4F5;
        }

        table.blueTable thead th:first-child {
            border-left: none;
        }

        .CVEred {
            background-color: #FF0000;
        }

        .CVEorange {
            background-color: #FF7002;
        }

        .CVEyellow {
            background-color: #FFD300;
        }

        .owner-filter {
            margin: 10px 0 16px 0;
        }

        .pill {
            display: inline-block;
            padding: 5px 14px;
            margin: 3px 3px 3px 0;
            border-radius: 20px;
            border: 1px solid #1C6EA4;
            cursor: pointer;
            background: #ffffff;
            color: #1C6EA4;
            font-size: 13px;
            font-weight: bold;
        }

        .pill.active {
            background: #1C6EA4;
            color: #ffffff;
        }

        .pill:hover:not(.active) {
            background: #D0E4F5;
        }

        .owner-filter-input {
            display: none;
        }
    </style>
</head>

<body>
EOF
}


writeOwnerFilter() {
    # $@ = unique owner names (sorted)

    # CSS-only approach: radio inputs + labels (works inside sandbox="" iframes).
    echo "    <input type='radio' id='owner-filter-all' name='owner-filter' class='owner-filter-input' checked>"
    echo "    <input type='radio' id='owner-filter-none' name='owner-filter' class='owner-filter-input'>"
    for owner in "$@"; do
        local safeId
        safeId="owner-filter-$(echo "$owner" | tr -cd '[:alnum:]-_')"
        echo "    <input type='radio' id='$safeId' name='owner-filter' class='owner-filter-input'>"
    done

    echo "    <style>"
    echo "        #owner-filter-all:checked ~ .owner-filter label[for='owner-filter-all'],"
    echo "        #owner-filter-none:checked ~ .owner-filter label[for='owner-filter-none'] { background: #1C6EA4; color: #ffffff; }"
    echo "        #owner-filter-none:checked ~ table.blueTable tr[data-owner] { display: none; }"
    for owner in "$@"; do
        local safeId
        safeId="owner-filter-$(echo "$owner" | tr -cd '[:alnum:]-_')"
        echo "        #${safeId}:checked ~ .owner-filter label[for='${safeId}'] { background: #1C6EA4; color: #ffffff; }"
        echo "        #${safeId}:checked ~ table.blueTable tr[data-owner] { display: none; }"
        echo "        #${safeId}:checked ~ table.blueTable tr[data-owner~='${owner}'] { display: table-row; }"
    done
    echo "    </style>"

    echo "    <div class='owner-filter'>"
    echo "        <label for='owner-filter-all' class='pill'>All</label>"
    echo "        <label for='owner-filter-none' class='pill'>None</label>"
    for owner in "$@"; do
        local safeId
        safeId="owner-filter-$(echo "$owner" | tr -cd '[:alnum:]-_')"
        echo "        <label for='$safeId' class='pill'>$owner</label>"
    done
    echo "    </div>"
}

writeHtmlTableHeaderSummary() {
    cat<<EOF
    <table class="blueTableSummary">
        <tbody>
EOF
}

writeHtmlTableHeader() {
    cat<<EOF
    <table class="blueTable">
        <thead>
            <tr>
                <th>Score</th>
                <th>CVE</th>
                <th>Project</th>
                <th>Owner</th>
                <th>Jira Tickets</th>
            </tr>
        </thead>
        <tbody>
EOF
}

writeHtmlTableTrailer() {
    cat<<EOF
        </tbody>
    </table>
EOF
}

writeHtmlTrailer() {
    cat<<EOF
</body>

</html>
EOF
}

# Search all dependency-check-report.xml files for CVE information using xmlstarlet.
scanForCves() {
    echo "Scanning code for CVE's"

    while read -r name; do
        echo "    doc:${name}"

        local cvelines
        cvelines=$(xmlstarlet sel \
            -t \
            -m "//_:dependencies/_:dependency/_:vulnerabilities/_:vulnerability" \
            -v '_:name' \
            -o '|' \
            -v '_:cvssV3/_:baseScore' \
            -o '|' \
            -v '_:cvssV2/_:score' \
            -n \
            "$name")

        if [[ $cvelines == "" ]]; then
            echo "        Skipping no cve's"
            continue
        fi

        # Get project name from the folder-name.
        local n
        n=$(echo "$name" | sed -e 's/.*workspace\/cve\///' -e 's/\/.*//')
        echo "    $n"

        while read -r cve; do
            IFS='|' read -r -a cveArray <<< "$cve"
            k="${cveArray[0]}"
            v3="${cveArray[1]}"
            v2="${cveArray[2]}"

            if [[ $v3 == "" ]]; then
            	v3="0.0"
            fi
            if [[ $v2 == "" ]]; then
            	v2="0.0"
            fi

            v2bigger=$(echo "$v2 >= $v3" | bc)

            if (( v2bigger > 0 )); then
                cves["$v2|$k|$n"]="$v2"
                echo "        $k | $v2"
            else
                cves["$v3|$k|$n"]="$v3"
                echo "        $k | $v3"
            fi
        done<<<"$cvelines"
    done <<<"$(find "$JENKINS_HOME/workspace/cve" -name dependency-check-report.xml -print)"
}

writeToTsv() {
    for key in "${!cves[@]}"; do
        IFS='|' read -r -a cveArray <<< "$key"
        local cvescore="${cveArray[0]}"
        local cveid="${cveArray[1]}"
        local projectName="${cveArray[2]}"
        local owner="${projectOwners[${projectName,,}]:-Unknown}"
        local bigger
        bigger=$(echo "$cvescore >= 7.0" | bc)

        if (( bigger > 0 )); then
            printf "%s\t%s\t%s\t%s\n" "$cvescore" "$cveid" "$projectName" "$owner"
        fi
    done | sort -n -r
}

writeSummary() {
    echo "Number of CVE's<br/>"

    writeHtmlTableHeaderSummary
    local riskyCves
    riskyCves=$(cut -f 1,2 < "$CVE_TSV_FILE" | sort -u)
    echo "<tr><td class='CVEred'>Jira Blocker/Highest (9.5 - 10.0): </td><td class='CVEred'>$(printf '%s' "$riskyCves" | grep -c -P '^(9|10)\.')</td></tr>"
    echo "<tr><td class='CVEorange'>Jira Critical/High (8.0 - 9.4): </td><td class='CVEorange'>$(printf '%s' "$riskyCves" | grep -c -P '^8\.')</td></tr>"
    echo "<tr><td class='CVEyellow'>Jira Major/Medium (7.0 - 7.9): </td><td class='CVEyellow'>$(printf '%s' "$riskyCves" | grep -c -P '^7\.')</td></tr>"

    writeHtmlTableTrailer

    echo "Note this colour scale is in Jira ticket priority, not CVE score severity see: <a target='_blank' href='https://en.wikipedia.org/wiki/Common_Vulnerability_Scoring_System#Version_3'>CVE Score V3</a><br/><br/>"
    echo "CVE Scores: Low (0.1-3.9), Medium (4.0-6.9), High (7.0-8.9), and Critical (9.0-10.0)<br/>"
    echo "<br/>"
    echo "Download spreadsheet of this table: <a href='cveTable.tsv' target='_top'>cveTable.tsv</a><br/>"
    echo "Generated: $(date)<br/>"
    echo "<br/>"
}

outCve() {
    local lastScore="$1"
    local lastCve="$2"
    local lastName="$3"
    local lastOwners="$4"
    local scoreclass
    local tickets
    local bigger70
    local bigger80
    local bigger95
    bigger70=$(echo "$lastScore >= 7.0" | bc)

    if (( bigger70 > 0 )); then
        bigger95=$(echo "$lastScore >= 9.5" | bc)
        bigger80=$(echo "$lastScore >= 8.0" | bc)

        if (( bigger95 > 0 )); then
            scoreclass="CVEred"
        elif (( bigger80 > 0 )); then
            scoreclass="CVEorange"
        else
            scoreclass="CVEyellow"
        fi

        tickets=$(findCveTickets "$lastCve")

        local displayOwners="${lastOwners// /, }"

        echo "            <tr data-owner='$lastOwners'>"
        echo "                <td class='$scoreclass'>$lastScore</td>"
        echo "                <td><a href='$CVE_URL/$lastCve' target='_top'>$lastCve</a></td>"
        echo "                <td>$lastName</td>"
        echo "                <td>$displayOwners</td>"

        echo "                <td style='text-align: left;'>"

        while IFS=$'\t' read -r id status text assignee priority; do
            if [[ $assignee == null ]]; then
                assignee='Unassigned'
            fi

            echo "                    <a href='$VIEW_URL$id' target='_top'>$id</a> <b>$status</b> : <i>$priority</i> : <b>$assignee</b> $text</br>"
        done<<<"${tickets}"
        echo "                </td>"

        echo "            </tr>"
    fi
}

writeToHtml() {
    # Pre-scan TSV to collect unique owners for filter pills
    declare -A ownerSet
    while IFS=$'\t' read -r _score _cve _module owner; do
        if [[ -n "$owner" ]]; then
            ownerSet["$owner"]=1
        fi
    done < "$CVE_TSV_FILE"
    mapfile -t sortedOwners < <(printf '%s\n' "${!ownerSet[@]}" | sort)

    writeHtmlHeader
    writeSummary
    writeOwnerFilter "${sortedOwners[@]}"
    writeHtmlTableHeader

    local lastScore="0.0"
    local lastCve=""
    local moduleList=""
    local ownerList=""
    local first=true
    local score
    local cve
    local module
    local owner

    while IFS=$'\t' read -r score cve module owner; do
        if $first; then
            lastScore="$score"
            lastCve="$cve"
            moduleList="<a href='$BUILD_URL/$module' target='_top'>$module</a>"
            ownerList="$owner"
            first=false
            continue
        fi

        if [[ "$lastCve" == "$cve" ]]; then
            moduleList="$moduleList,<br/><a href='$BUILD_URL/$module' target='_top'>$module</a>"
            # Append owner only if not already in the space-separated list
            if [[ " ${ownerList} " != *" ${owner} "* ]]; then
                ownerList="${ownerList} ${owner}"
            fi
        else
            outCve "$lastScore" "$lastCve" "$moduleList" "$ownerList"
            lastScore="$score"
            lastCve="$cve"
            moduleList="<a href='$BUILD_URL/$module' target='_top'>$module</a>"
            ownerList="$owner"
        fi
    done<"$CVE_TSV_FILE"

    if [[ $lastCve != "" ]]; then
        outCve "$lastScore" "$lastCve" "$moduleList" "$ownerList"
    fi

    writeHtmlTableTrailer
    writeHtmlTrailer
}

if [[ $1 == tsv ]]; then
    declare -A cves
    declare -A projectOwners
    loadOwnerMap "$2"
    scanForCves

    echo "Writing to $CVE_TSV_FILE"
    writeToTsv > "$CVE_TSV_FILE"

elif [[ $1 == html ]]; then
    echo "Writing to $CVE_HTML_FILE"
    writeToHtml > "$CVE_HTML_FILE"

else
    echo "Specify tsv or html."
fi
