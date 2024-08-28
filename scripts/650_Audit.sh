#!/usr/bin/env bash
source "$SCRIPTS_PATH/000_Config.sh"
figlet -w 500 "Audit"

case ${SNOMED_PROJECT_LANGUAGE,,} in
    javascript)
        echo "Not performing sonar check."
        ;;

    typescript)
        cat>sonar-project.properties<<EOF
sonar.projectKey=${SNOMED_PROJECT_GROUP_ARTIFACT,,}
sonar.projectName=${SNOMED_PROJECT_NAME,,}
sonar.projectVersion=1.0
sonar.sources=src
sonar.tests=src
sonar.language=ts
sonar.test.inclusions=.
sonar.exclusions=src/main/**/*,node_modules/**/*,.angular/**/*,dist/**/*
sonar.sourceEncoding=UTF-8
EOF

        node_modules/sonarqube-scanner/bin/sonar-scanner -Dsonar.host.url=${SONAR_URL} -Dsonar.login=${SONAR_TOKEN}
        ;;
    *)
        case ${SNOMED_PROJECT_BUILD_TOOL,,} in
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
        ;;
esac
