#!/usr/bin/env bash
source "$SCRIPTS_PATH/000_Config.sh"
figlet -w 500 "Unit Testing"

case ${SNOMED_PROJECT_LANGUAGE,,} in
    cypress)
        echo "No test tool required."
        ;;
    javascript)
        echo "No test tool required at the moment."
        ;;
    typescript)
        echo "No test tool required at the moment."
        # ng test
        ;;
    *)
        case $SNOMED_PROJECT_BUILD_TOOL in
            maven)
                mvn test surefire-report:report -Ddependency-check.skip=true
                ;;
            gradle)
                ./gradlew test
                ;;
            none)
                echo "No test tool required."
                ;;
            *)
                echo "Unknown build tool: ${SNOMED_PROJECT_BUILD_TOOL}"
                exit 1
                ;;
        esac
    ;;
esac
