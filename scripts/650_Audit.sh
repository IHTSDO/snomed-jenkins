#!/usr/bin/env bash
source "$SCRIPTS_PATH/000_Config.sh"
figlet -w 500 "Audit"

case $SNOMED_PROJECT_BUILD_TOOL in
    maven)
        mvn \
            -DskipTests \
            -Ddependency-check.skip=true \
            -Dsonar.host.url="${SONAR_URL}" \
            -Dsonar.token="${SONAR_TOKEN}" \
            -Dsonar.projectName="${SNOMED_PROJECT_NAME,,}" \
            sonar:sonar -Dsonar.qualitygate.wait=true
        ;;
    gradle)
        # https://docs.sonarsource.com/sonarqube/latest/analyzing-source-code/scanners/sonarscanner-for-gradle/
        gradle sonar \
            -Dsonar.verbose=true \
            -Dsonar.host.url="${SONAR_URL}" \
            -Dsonar.token="${SONAR_TOKEN}"
        ;;
    none)
        echo "No audit tool required."
        ;;
    *)
        echo "Unknown build tool: ${SNOMED_PROJECT_BUILD_TOOL}"
        exit 1
        ;;
esac
