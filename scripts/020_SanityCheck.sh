#!/usr/bin/env bash
source "$SCRIPTS_PATH/000_Config.sh"
figlet -w 500 "Sanity Check Project"

LICENSE_FILE="LICENSE.md"

mavenSanity() {
    if [[ -e pom.xml ]]; then
        # Required here to ensure that the pom.xml file includes the JaCoCo plugin prior to test.
        # TODO: Make part of projects pom, so we don't hack in this way.
        echo "Adjusting pom.xml"

        while read -r pomfile; do
            echo "$pomfile"
            sed -i '/<plugins>/r /var/lib/jenkins/workspace/_PipelineCreationJob_/resources/JaCoCo/jacoco.xml' "$pomfile"
        done<<<"$(find . -type f -name pom.xml)"
    else
        echo "Missing pom.xml"
        exit 1
    fi

    echo "Maven pom.xml exists."
}

gradleSanity() {
    if [[ ! -e build.gradle ]]; then
        echo "Missing build.gradle"
        exit 1
    fi

    echo "Gradle build.gradle exists."
}

checkLicense() {
    if [[ ! -e "$LICENSE_FILE" ]]; then
        echo "Missing $LICENSE_FILE"
        exit 1
    fi

    CHKSUM=$(grep -v "Copyright .*, SNOMED International" "$LICENSE_FILE" | md5sum | awk '{print $1}')

    if [[ "$CHKSUM" != "$LICENSE_EXPECTED_CHECK_SUM" ]]; then
        echo "Invalid contents of $LICENSE_FILE"
        echo "     Expected   : $LICENSE_EXPECTED_CHECK_SUM"
        echo "     Calculated : $CHKSUM"
        exit 1
    fi

    echo "$LICENSE_FILE file OK"
}

checkLicense

case $SNOMED_PROJECT_BUILD_TOOL in
    maven)
        mavenSanity
        ;;
    gradle)
        gradleSanity
        ;;
    none)
        echo "No build tool required."
        ;;
    *)
        echo "Unknown build tool: ${SNOMED_PROJECT_BUILD_TOOL}"
        exit 1
        ;;
esac
