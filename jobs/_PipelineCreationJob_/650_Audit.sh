#!/usr/bin/env bash
source ../_PipelineCreationJob_/jobs/_PipelineCreationJob_/000_Config.sh
figlet -w 500 "${STAGE_NAME}"

case $SNOMED_PROJECT_BUILD_TOOL in
    maven)
        if [[ $HOSTNAME =~ dev-jenkins* ]]; then
            echo "Not running SonarQube on dev-jenkins."
        else
            mvn sonar:sonar
        fi
        ;;
    gradle)
        echo "SonarQube not implemented for gradle."
        ;;
    none)
        echo "No audit tool required."
        ;;
    *)
        echo "Unknown build tool: ${SNOMED_PROJECT_BUILD_TOOL}"
        exit 1
        ;;
esac


