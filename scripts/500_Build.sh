#!/usr/bin/env bash
source "$SCRIPTS_PATH/000_Config.sh"
figlet -w 500 "Build"

case $SNOMED_PROJECT_LANGUAGE in
    Cypress)
        npm install
        ng build
        ;;
    Embedded)
        SNOMED_UI_REF=$(python3 -c "import xml.etree.ElementTree as ET; print(ET.parse('pom.xml').getroot().find('./properties/snomed-ui.version').text)")
        APP_DIR=$(pwd)
        git clone --branch "$SNOMED_UI_REF" --depth 1 \
            git@github.com:IHTSDO/snomed-ui.git _snomed_ui_workspace
        ln -s "$APP_DIR" _snomed_ui_workspace/projects/$SNOMED_PROJECT_NAME
        cd _snomed_ui_workspace
        mvn -U clean package -DskipTests -Ddependency-check.skip=true
        npm install
        npm run build:lib
        npm run build:$SNOMED_PROJECT_NAME
        ;;
    Javascript)
        gem list -i sass || gem install sass
        mvn -U clean package -DskipTests -Ddependency-check.skip=true
        ;;
    *)
        case $SNOMED_PROJECT_BUILD_TOOL in
            maven)
                mvn -U clean package -DskipTests -Ddependency-check.skip=true
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