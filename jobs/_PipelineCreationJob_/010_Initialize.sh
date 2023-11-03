#!/usr/bin/env bash
source ../_PipelineCreationJob_/000_Config.sh
figlet -w 500 "${STAGE_NAME}"

echo "---------------------------------------------------------------"
java --version
echo "---------------------------------------------------------------"
echo "BUILD TOOL: ${SNOMED_PROJECT_BUILD_TOOL}"

case $SNOMED_PROJECT_BUILD_TOOL in
    maven)
        mvn --version
        ;;
    gradle)
        gradle --version
        ;;
    none)
        echo "No build tool required."
        ;;
    *)
        echo "Unknown build tool: ${SNOMED_PROJECT_BUILD_TOOL}"
        exit 1
        ;;
esac

echo "---------------------------------------------------------------"
set
echo "---------------------------------------------------------------"
