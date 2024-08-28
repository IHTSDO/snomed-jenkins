#!/usr/bin/env bash
source "$SCRIPTS_PATH/000_Config.sh"
figlet -w 500 "CVE/Security Checks"

set -e

case ${SNOMED_PROJECT_LANGUAGE,,} in
    cypress | typescript | javascript)
        echo "No security tool required."
        ;;
    *)
        case $SNOMED_PROJECT_BUILD_TOOL in
            maven)
                mvn dependency-check:check -DskipTests

                # Always make empty report file.
                if [[ ! -d "target" ]]; then
                    mkdir target
                fi

                touch "target/dependency-check-report.xml"
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
