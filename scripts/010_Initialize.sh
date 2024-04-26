#!/usr/bin/env bash
source "$SCRIPTS_PATH/000_Config.sh"
figlet -w 500 "Initialise"

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

if $VERBOSE; then
    echo "---------------------------------------------------------------"
    set
fi

echo "---------------------------------------------------------------"
