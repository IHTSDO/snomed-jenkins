#!/usr/bin/env bash
source ../_PipelineCreationJob_/000_Config.sh
figlet -w 500 "${STAGE_NAME}"

case $SNOMED_PROJECT_BUILD_TOOL in
    maven)
        mvn jacoco:report -Ddependency-check.skip=true
        ;;
    gradle)
        # echo "No quality checks for gradle projects as yet."
        ./gradlew clean build buildDeb -x test -x spotbugsMain -x spotbugsTest
        ./gradlew clean build buildDeb -x test -x checkstyleTest -x checkstyleMain
        ;;
    none)
        echo "No build tool required."
        ;;
    *)
        echo "Unknown build tool: ${SNOMED_PROJECT_BUILD_TOOL}"
        exit 1
        ;;
esac
