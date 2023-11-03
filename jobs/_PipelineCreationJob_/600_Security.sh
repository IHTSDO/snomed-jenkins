#!/usr/bin/env bash
source ../_PipelineCreationJob_/000_Config.sh
figlet -w 500 "${STAGE_NAME}"

case $SNOMED_PROJECT_BUILD_TOOL in
    maven)
        mvn dependency-check:check -DskipTests
        ;;
    gradle)
        ./gradlew dependencyCheckAnalyze --continue
        ;;
    none)
        echo "No build tool required."
        ;;
    *)
        echo "Unknown build tool: ${SNOMED_PROJECT_BUILD_TOOL}"
        exit 1
        ;;
esac


