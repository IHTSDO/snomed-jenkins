#!/usr/bin/env bash
source ../_PipelineCreationJob_/000_Config.sh
figlet -w 500 "${STAGE_NAME}"

case $SNOMED_PROJECT_LANGUAGE in
    Cypress|Typescript|Javascript)
        echo "No security tool required."
        ;;
    *)
        case $SNOMED_PROJECT_BUILD_TOOL in
            maven)
                mvn dependency-check:check -DskipTests || true
                exit 0
                ;;
            gradle)
                ./gradlew dependencyCheckAnalyze --continue
                ;;
            none)
                echo "No security tool required."
                ;;
            *)
                echo "Unknown build tool: ${SNOMED_PROJECT_BUILD_TOOL}"
                exit 1
                ;;
        esac
    ;;
esac
