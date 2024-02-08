#!/usr/bin/env bash
source ../_PipelineCreationJob_/jobs/_PipelineCreationJob_/000_Config.sh
figlet -w 500 "${STAGE_NAME}"

runDoxygenOnBuild() {
    echo "---------------------------------------------------------------"
    echo "Adjusting Doxyfile for ${SNOMED_PROJECT_NICE_NAME=}"
    cp "$JENKINS_HOME/snomed-jenkins/jobs/resources/Doxygen/Doxyfile" .
    sed -i "s/SNOMED_PROJECT_NAME/${SNOMED_PROJECT_NICE_NAME=}/" Doxyfile
    sed -i "s/SNOMED_RESOURCE_FOLDER/${JENKINS_HOME//\//\\\/}\/snomed-jenkins\/jobs\/resources\/Doxygen/" Doxyfile
    echo "---------------------------------------------------------------"

    doxygen || true
}

case $SNOMED_PROJECT_LANGUAGE in
    Cypress|Typescript|Javascript)
        echo "No documentation required for this project."
        ;;
    *)
        runDoxygenOnBuild
        ;;
esac
