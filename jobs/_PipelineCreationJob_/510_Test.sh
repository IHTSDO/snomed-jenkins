#!/usr/bin/env bash
source ../_PipelineCreationJob_/000_Config.sh
figlet -w 500 "${STAGE_NAME}"

case $SNOMED_PROJECT_BUILD_TOOL in
    maven)
        mvn test surefire-report:report -Ddependency-check.skip=true
        ;;
    gradle)
        ./gradlew test
        ;;
    none)
        echo "No build tool required."
        ;;
    *)
        echo "Unknown build tool: ${SNOMED_PROJECT_BUILD_TOOL}"
        exit 1
        ;;
esac

