#!/usr/bin/env bash
# Graphviz syntax reference: https://graphviz.org
# Colours: https://graphviz.org/doc/info/colors.html#brewer

LOC=$JENKINS_HOME/userContent
PNG_FILE=$LOC/depGraph.png
SVG_FILE=$LOC/depGraph.svg
LINK_FILE=$LOC/depLinks.txt
DOT_FILE=$LOC/depGraph.dot
CVE_FILE=$LOC/cveTable.tsv
HTML_FILE=$LOC/depGraph.html
PNG_URL=${JENKINS_URL}userContent/depGraph.png
PNG_URL_SHORT=/userContent/depGraph.png
SVG_URL=${JENKINS_URL}userContent/depGraph.svg

makeDependencyGraph() {
    cat << EOF > "$HTML_FILE"
<!DOCTYPE html>
<html>
<head>
    <title>Dep Graph</title>
</head>
<body>
	<div>
	  <img src="${PNG_URL}"/>
		<a href="${SVG_URL}">
			<img src="${PNG_URL}"/>
		</a>
	  <img src="${PNG_URL_SHORT}"/>
		<a href="${SVG_URL}">
			<img src="${PNG_URL_SHORT}"/>
		</a>
	</div>
</body>
</html>
EOF
}

prepareFiles() {
    for file in "$PNG_FILE" "$DOT_FILE" "$LINK_FILE"; do
        if [[ -e "$file" ]]; then
            rm "$file"
        fi
    done
}

fixLabel() {
    echo "${1,,}" | sed -e 's/\//_/g' -e 's/\./_/g' -e 's/-/_/g' -e 's/:/__/g'
}

fixCve() {
    echo "${1^^}" | sed -e 's/-/_/g'
}

makeLink() {
    local g="$( fixLabel "$1")"
    local a="$( fixLabel "$2")"
    local p="$( fixLabel "$3")"

    if [[ "$a" == "snomed_parent_owasp" ]]; then
        echo "org_snomed__snomed_parent_owasp"
    elif [[ -z $p ]]; then
        echo "$( fixLabel "$4")_UNKNOWN"
    else
        echo "${g}__$p:$a"
    fi
}

printHeader() {
    cat << EOF
digraph g {
    fontname="Arial"
    node [fontname="courier" fontsize=12 style="filled, bold, rounded" penwidth=1 fillcolor = "/blues4/1:/blues4/3" shape="none" fontcolor="red"];
    edge [fontname="courier" fontsize=8]
    graph [fontsize=20 labelloc="top" splines=true overlap=false rankdir = "LR" label="SNOMED Code Estate"]
    ratio = auto;

EOF
}

printLegend() {
    cat << EOF

    // Legend
    subgraph clusterLegend {
        rank = sink;
        label = "Legend";

        project [fontcolor="black" fillcolor="/greens4/1:/greens4/3" label=<<table border='0'>
            <tr><td port='parent'><font point-size='12'><b>Parent Project (bold=parent, green background=Uses BOM)</b></font></td></tr>
            <tr><td port='child1' align='right'><font point-size='11'>Sub Project 1 (non-bold=child)</font></td></tr>
            <tr><td port='child2' align='right'><font point-size='11'>Sub Project 2 (non-bold=child)</font></td></tr>
            </table>>]
        project2 [fontcolor="black" fillcolor="/blues4/1:/blues4/3" label=<<table border='0'>
            <tr><td port='parent'><font point-size='12'><b>Parent Project (blue background=Does not use BOM)</b></font></td></tr>
            <tr><td port='child1' align='right'><font point-size='11'>Sub Project 1</font></td></tr>
            <tr><td port='child2' align='right'><font point-size='11'>Sub Project 2</font></td></tr>
            </table>>]
        project3 [fontcolor="black" fillcolor="/greens4/1:/greens4/3" label=<<table border='0'>
                <tr><td port='parent'><font point-size='12'><b>The BOM</b></font></td></tr>
            </table>>]
        project4 [fontcolor="black" fillcolor="/reds4/1:/reds4/3" label=<<table border='0'>
            <tr><td port='parent'><font point-size='12'><b>CVE-111-12345</b>  8.5  (A CVE with its risk score)</font></td></tr>
            </table>>]
        project5 [fontcolor="black" fillcolor="/blues4/1:/blues4/3" label=<<table border='0'>
            <tr><td port='parent'><font point-size='12' color="red">Unknown SNOMED project (name in red)</font></td></tr>
            </table>>]
        project6 [fontcolor="black" fillcolor="/oranges4/1:/oranges4/3" label=<<table border='0'>
            <tr><td port='parent'><font point-size='12' color="red">Kai/non-snomed project</font></td></tr>
            </table>>]
        project:parent -> project4:parent [ color=red label="Link to CVE is red"]
        project:parent -> project3:parent [ color=gray style=dashed label="Link to BOM is grey dashed"]
        project:child1 -> project2:child1 [ color=black ]
        project:child1 -> project5:parent [ color=black label="Link to unknown project"]
        project:child1 -> project6:parent [ color=red label="Link to kai project"]
    }

EOF
}

printTrailer() {
    cat << EOF

    // END
}
EOF
}

printCVEs() {
    echo
    echo "    // CVE nodes, labelled as CVE_123_1234"
    declare -A cveSeen

    while read -r line; do
        IFS=$'\t' read -r -d$'\1' score cve project <<< "${line}"

        if [[ -z ${cveSeen["$cve"]} ]]; then
            cveSeen["$cve"]="seen"
        else
            continue
        fi

        node=$(fixCve "$cve")
        echo "    $node [fontcolor=\"black\" fillcolor=\"/reds4/3:/reds4/2\" fontname=\"courier\" label=<<table border=\"0\">"
        echo "            <tr><td><b>${cve}</b></td><td>${score}</td></tr>"
        echo "        </table>>];"
    done < "$CVE_FILE"

    echo
    echo "    // Links from projects to CVE"
    while read -r line; do
        IFS=$'\t\n' read -r -d$'\1' score cve project <<< "${line}"

        for key in "${!projectMap[@]}"; do
            val=${projectMap[$key]}

            if [[ $val == "$project" ]]; then
                  gId="${key%:*}"
                  aId="${key%%*:}"
                    fromLink=$(makeLink "$gId" "$aId" "$project" "")
                    toLink=$(fixCve "$cve")
                    echo "    $fromLink -> $toLink [color=red]"
                    break
            fi
        done
    done < "$CVE_FILE"

    echo
}

generateDotFile() {
    echo "Generating graph from pom.xml files found in this folder down: $PWD"

    {
        printHeader
        printLegend
        #        printCVEs

        echo "    org_snomed__snomed_parent_owasp [fontcolor=\"black\" fillcolor=\"/greens4/1:/greens4/3\" label=<<table border='0'>"
        echo "        <tr><td port='snomed_parent_owasp'><font point-size='12'><b>snomed_parent_owasp</b></font></td></tr>"
        echo "    </table>>];"


        for pom in */pom.xml; do
            processPom true "$pom"
        done

        for pom in */*/pom.xml; do
            processPom false "$pom"
        done

        printTrailer
    } >> "$DOT_FILE"
}

processPom() {
    local outputNode=$1
    local pom=$2

    local gId=$(xmllint --xpath '/*[local-name()="project"]/*[local-name()="groupId"]/text()' "$pom" 2>&1 | sed -e 's/XPath set is empty/-/g')
    local aId=$(xmllint --xpath '/*[local-name()="project"]/*[local-name()="artifactId"]/text()' "$pom" 2>&1 | sed -e 's/XPath set is empty/-/g')
    local modules=$(xmllint --xpath '/*[local-name()="project"]/*[local-name()="modules"]/*[local-name()="module"]/text()' "$pom" 2>&1 | sed -e 's/XPath set is empty/-/g')
    local deps=$(xmllint --xpath '/*[local-name()="project"]/*[local-name()="dependencies"]/*[local-name()="dependency"]' "$pom" 2>&1 | sed -e 's/XPath set is empty/-/g')
    local dList=$(echo "$deps" | tr -d \\n | sed -e 's/<\/groupId>[^<]*<artifactId>/:/g' -e 's/<\/artifactId>/\n/g' -e 's/>/>\n/g' | sort -u | grep -v '<')
    local bom=$(xmllint --xpath '/*[local-name()="project"]/*[local-name()="parent"]/*[local-name()="artifactId"]/text()' "$pom" 2>&1 | sed -e 's/XPath set is empty/-/g')

    local pomFolder="${pom//\/pom.xml/}"
    local parentPom="$pomFolder/../pom.xml"

    if [[ -e $parentPom ]]; then
        gId=$(xmllint --xpath '/*[local-name()="project"]/*[local-name()="groupId"]/text()' "$parentPom" 2>&1 | sed -e 's/XPath set is empty/-/g')
    fi

    if [[ $gId == '-' ]]; then
        gId="org.snomed"
    fi

    if [[ $modules == '-' ]]; then
        modules=""
    fi

    id="$gId:$aId"
    local projectName=${projectMap["$id"]}
    local nodeId="$gId:${projectMap[$id]}"
    local nodeIdLinkable=$( fixLabel "$nodeId")
    local projectNameLinkable="$( fixLabel "$projectName")"
    echo "    // POM         : $pom"
    echo "    //     gId:aId : $id / ${projectMap["$id"]} / $nodeId"

    if $outputNode; then
        echo -n "    $nodeIdLinkable [fontcolor=\"black\" "

        if [[ $bom == "snomed-parent-bom" ]] || [[ $id == org.snomed:snomed-parent-bom ]] || [[ $id == org.snomed:snomed-parent-owasp ]]; then
            echo -n "fillcolor=\"/greens4/1:/greens4/3\""
        fi

        echo " label=<<table border='0'>"
        echo "            <tr><td port='$projectNameLinkable'><font point-size='12'><b>$projectName</b></font></td></tr>"

        for line in $modules; do
            anchor=$(fixLabel "$line")
            echo "        <tr><td port='$anchor' align='right'><font point-size='11'>$line</font></td></tr>"
        done

        echo "        </table>>];"
    fi

    local fromLink=$(makeLink "$gId" "$aId" "$projectName" "")

    for dep in $dList; do
        linkcol="black"
        render=false

        if [[ $dep =~ snomed ]]; then
            render=true
        fi

        if [[ $dep =~ ihtsdo ]]; then
            render=true
        fi

        if $render; then
            depGid=$(echo "$dep" | cut -d: -f1)
            depAid=$(echo "$dep" | cut -d: -f2)
            depProjectName="${projectMap["$dep"]}"
            toLink=$(makeLink "$depGid" "$depAid" "$depProjectName" "$dep")
            echo "    $fromLink -> $toLink [color=$linkcol]"
        fi
    done

    if $outputNode && [[ $bom == "snomed-parent-bom" ]]; then
        echo "    $fromLink -> org_snomed__snomed_parent_bom [color=gray style=dashed]"
    fi

    echo
}

convertDotToPngAndSvg() {
    echo "Generating $PNG_FILE from $DOT_FILE"
    dot -Tpng "$DOT_FILE" -o "$PNG_FILE"
    dot -Tsvg "$DOT_FILE" -o "$SVG_FILE"
    mogrify -resize 1366x "$PNG_FILE"
    echo "Done"
}

createProjectMap() {
    echo "Creating project map"

    for pom in */pom.xml; do
        addToProjectMap true "$pom"
    done

    for pom in */*/pom.xml; do
        addToProjectMap false "$pom"
    done

    echo "Number of projects/sub-projects : ${#projectMap[@]}"
}

addToProjectMap() {
    local topLevel=$1
    local pom=$2

    local gId=$(xmllint --xpath '/*[local-name()="project"]/*[local-name()="groupId"]/text()' "$pom" 2>&1 | sed -e 's/XPath set is empty/-/g')
    local aId=$(xmllint --xpath '/*[local-name()="project"]/*[local-name()="artifactId"]/text()' "$pom" 2>&1 | sed -e 's/XPath set is empty/-/g')
    local pomFolder="${pom//\/pom.xml/}"
    local parentPom="$pomFolder/../pom.xml"

    if [[ -e $parentPom ]]; then
        gId=$(xmllint --xpath '/*[local-name()="project"]/*[local-name()="groupId"]/text()' "$parentPom" 2>&1 | sed -e 's/XPath set is empty/-/g')
    fi

    if [[ $gId == '-' ]]; then
        gId="org.snomed"
    fi

    if $topLevel; then
        projectName="$pomFolder"
    else
        projectName="${pomFolder%/*}"
    fi

    projectMap["$gId:$aId"]="$projectName"
    echo "    projectMap[ $gId : $aId ]= $projectName"
}

makeLinkFile() {
    echo "Generating $LINK_FILE from $DOT_FILE, the dependencies"

    grep " -> " "$DOT_FILE" |
          grep -v " project:" |
          grep -v " CVE_" |
          sed -e 's/^ *//' \
              -e 's/ -> /\t/' \
              -e 's/__/:/g' \
              -e 's/_/-/g' \
              -e 's/ *\[.*$//' |
          sort -u > "$LINK_FILE"

    # Join to 1 line per project with comma separator for each dependency.
    perl -p0E 'while(s/^((.+?)\t.*)\n\2\t/$1,/gm){}' -i "$LINK_FILE"

    echo "Done"
    echo Use the depGraph.txt file to replace contents of DepList tab https://docs.google.com/spreadsheets/d/13Hdd_hf1HbUAUVbMbzZgQPQIkQ_gI8rGZ9IS3WvK5iM/edit#gid=0
}

declare -A projectMap

cd "$JENKINS_HOME/workspace/cve" || exit 1

prepareFiles
createProjectMap
generateDotFile
convertDotToPngAndSvg
makeLinkFile
makeDependencyGraph
