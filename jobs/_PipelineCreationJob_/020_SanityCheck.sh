#!/usr/bin/env bash
source ../_PipelineCreationJob_/jobs/_PipelineCreationJob_/000_Config.sh
figlet -w 500 "${STAGE_NAME}"

mavenSanity() {
    if [[ -e pom.xml ]]; then
        # Required here to ensure that the pom.xml file includes the JaCoCo plugin prior to test.
        # TODO: Make part of projects pom, so we don't hack in this way.
        echo "Adjusting pom.xml"

        while read -r pomfile; do
            echo "$pomfile"
            sed -i '/<plugins>/r /var/lib/jenkins/snomed-jenkins/jobs/resources/JaCoCo/jacoco.xml' "$pomfile"
        done<<<"$(find . -type f -name pom.xml)"
    else
        echo "Missing pom.xml"
        exit 1
    fi
}

gradleSanity() {
    if [[ ! -e build.gradle ]]; then
        echo "Missing build.gradle"
        exit 1
    fi
}

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
