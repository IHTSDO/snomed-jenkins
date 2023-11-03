#!/usr/bin/env bash
source ../_PipelineCreationJob_/000_Config.sh
figlet -w 500 "${STAGE_NAME}"

echo "---------------------------------------------------------------"
echo "Adjusting Doxyfile for ${SNOMED_PROJECT_NICE_NAME=}"
cp $JENKINS_HOME/snomed-jenkins/jobs/resources/Doxygen/Doxyfile .
sed -i "s/SNOMED_PROJECT_NAME/${SNOMED_PROJECT_NICE_NAME=}/" Doxyfile
sed -i "s/SNOMED_RESOURCE_FOLDER/${JENKINS_HOME//\//\\\/}\/snomed-jenkins\/jobs\/resources\/Doxygen/" Doxyfile
echo "---------------------------------------------------------------"

doxygen || true
