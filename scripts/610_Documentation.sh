#!/usr/bin/env bash
source "$SCRIPTS_PATH/000_Config.sh"
figlet -w 500 "Documentation"

runDoxygenOnBuild() {
    echo "---------------------------------------------------------------"
    echo "Adjusting Doxyfile for ${SNOMED_PROJECT_NICE_NAME=}"
    cp "$SCRIPTS_PATH/../resources/Doxygen/Doxyfile" .
    sed -i "s/SNOMED_PROJECT_NAME/${SNOMED_PROJECT_NICE_NAME=}/" Doxyfile
    sed -i "s/SNOMED_RESOURCE_FOLDER/${JENKINS_HOME//\//\\\/}\/workspace\/_PipelineCreationJob_\/resources\/Doxygen/" Doxyfile
    echo "---------------------------------------------------------------"

    doxygen || true
}

case ${SNOMED_PROJECT_LANGUAGE,,} in
    cypress|typescript|javascript)
        echo "No documentation required for this project."
        ;;
    *)
        runDoxygenOnBuild
        ;;
esac
