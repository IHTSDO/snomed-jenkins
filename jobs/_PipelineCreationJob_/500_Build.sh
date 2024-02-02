#!/usr/bin/env bash
source ../_PipelineCreationJob_/000_Config.sh
figlet -w 500 "${STAGE_NAME}"

case $SNOMED_PROJECT_LANGUAGE in
    Cypress|Typescript|Javascript)
        npm install
        ng build
        ;;
    *)
        case $SNOMED_PROJECT_BUILD_TOOL in
            maven)
                mvn clean package -DskipTests -Ddependency-check.skip=true
                ;;
            gradle)
                ./gradlew clean build buildDeb -x test -x spotbugsMain -x spotbugsTest -x checkstyleTest -x checkstyleMain
                ;;
            none)
                echo "No build tool required."
                ;;
            *)
                echo "Unknown build tool: ${SNOMED_PROJECT_BUILD_TOOL}"
                exit 1
                ;;
        esac
    ;;
esac
