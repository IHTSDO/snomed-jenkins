#!/usr/bin/env bash
source "$SCRIPTS_PATH/000_Config.sh"
figlet -w 500 "Code Quality"

case ${SNOMED_PROJECT_LANGUAGE,,} in
    cypress|typescript|javascript)
        echo "No quality tool required."
        # ng lint
        ;;
    *)
        case $SNOMED_PROJECT_BUILD_TOOL in
            maven)
                # Search for jacoco setup in pom, if its there run the jacoco report.
                grep "<artifactId>jacoco-maven-plugin</artifactId>" pom.xml
                retval=$?

                if (( retval == 0 )); then
                    mvn jacoco:report -Ddependency-check.skip=true
                fi
                ;;
            gradle)
                # echo "No quality checks for gradle projects as yet."
                ./gradlew clean build buildDeb -x test -x spotbugsMain -x spotbugsTest
                ./gradlew clean build buildDeb -x test -x checkstyleTest -x checkstyleMain
                ;;
            none)
                echo "No quality tool required."
                ;;
            *)
                echo "Unknown build tool: ${SNOMED_PROJECT_BUILD_TOOL}"
                exit 1
                ;;
        esac
    ;;
esac
