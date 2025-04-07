#!/usr/bin/env bash
source "$SCRIPTS_PATH/000_Config.sh"
figlet -w 500 "Sanity Check Project"
set -e

LICENSE_FILE="LICENSE.md"
GITLEAKSWHITELIST="$SCRIPTS_PATH/../resources/gitleaks/gitleakrule.toml"
SENSITIVE_WORD_LIST="ihtsdotools.org snomedtools.org sct2 der2 gitleaks:allow" # SNOMED_SANITY_IGNORE
FAILED_CHECKS=false

checkLicense() {
    if [[ ! -e "$LICENSE_FILE" ]]; then
        echo "Missing $LICENSE_FILE"
        exit 1
    fi

    CHKSUM=$(grep -v "Copyright .*, SNOMED International" "$LICENSE_FILE" | md5sum | awk '{print $1}')

    if [[ "$CHKSUM" != "$LICENSE_EXPECTED_CHECK_SUM" ]]; then
        echo "Invalid contents of $LICENSE_FILE"
        echo "     Expected   : $LICENSE_EXPECTED_CHECK_SUM"
        echo "     Calculated : $CHKSUM"
        exit 1
    fi

    echo "$LICENSE_FILE file OK"
}

mavenSanity() {
    if [[ ! -e pom.xml ]]; then
        echo "Missing pom.xml"
        exit 1
    fi

    echo "Maven pom.xml exists."
}

gradleSanity() {
    if [[ ! -e build.gradle ]]; then
        echo "Missing build.gradle"
        exit 1
    fi

    echo "Gradle build.gradle exists."
}

gitLeaksCheck() {
    if [[ "${SNOMED_PROJECT_LANGUAGE,,}" == "javascript" ]]; then
        echo "Not performing Gitleaks check."
    else 
      echo "--------------------------------------------------------------------------------"
      echo "GitLeaks check"
      GITLEAKS="gitleaks"

      if [[ -e /opt/gitleaks/gitleaks ]]; then
          GITLEAKS="/opt/gitleaks/gitleaks"
      fi

      # Add "|| true" to following line to allow builds to continue even if gitleaks finds an issue.
      $GITLEAKS -c "$GITLEAKSWHITELIST" detect --source . -v
    fi
}

checkText() {
    TXT=$1
    count=$(grep -R -n --exclude-dir=target "$TXT" ./* | grep -v SNOMED_SANITY_IGNORE | wc -l)
    echo "--------------------------------------------------------------------------------"

    if (( count > 0 )); then
        echo "Fail: Found $count hits : $TXT"
        grep -R -n --exclude-dir=target "$TXT" ./* | grep -v SNOMED_SANITY_IGNORE
        # FAILED_CHECKS=true
    else
        echo "Pass: Did not find : $TXT"
    fi
}

checkLicense

case $SNOMED_PROJECT_BUILD_TOOL in
    maven)
        mavenSanity
        ;;
    gradle)
        gradleSanity
        ;;
    none)
        echo "No build tool required."
        ;;
    *)
        echo "Unknown build tool: ${SNOMED_PROJECT_BUILD_TOOL}"
        exit 1
        ;;
esac

figlet -w 500 "DevOps Checks"
gitLeaksCheck

for word in $SENSITIVE_WORD_LIST
do
    checkText "$word"
done

echo "--------------------------------------------------------------------------------"

if $FAILED_CHECKS; then
    echo "DevOps Sanity check failed"
    exit 2
else
    echo "DevOps Sanity Check Completed OK"
fi
