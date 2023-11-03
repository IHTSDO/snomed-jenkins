#!/usr/bin/env bash
source ../_PipelineCreationJob_/000_Config.sh
figlet -w 500 "${STAGE_NAME}"

deployDebianPackages() {
    echo "Uploading to Nexus"
    local rel_type="NONE"

    if [[ $GIT_BRANCH =~ master$ ]]; then
        rel_type="debian-releases"
    elif [[ $GIT_BRANCH =~ main$ ]]; then
        rel_type="debian-releases"
    elif [[ $GIT_BRANCH =~ develop$ ]]; then
        rel_type="debian-snapshots"
    else
        echo "Not main/master or develop branch, not uploading to Nexus"
    fi

    if [[ $rel_type =~ debian* ]]; then
        # Build the debian package.
        mvn install -Pdeb -Dmaven.test.skip=true -Ddependency-check.skip=true

        # Is it there?
        deb_pkg_count=$(find . -name "*.deb" -print -quit | wc -l)

        if (( deb_pkg_count > 0 )); then
            deb_pkg=$(find . -name "*.deb" -print -quit)

            if [[ -e ${deb_pkg} ]]; then
                echo "File to upload is: ${deb_pkg}"

                # See example 7 here: https://www.jenkins.io/doc/book/pipeline/syntax/#environment
                status=$(curl -o /dev/null --write-out '%{http_code}\n' -u "$NEXUS_LOGIN_USR:$NEXUS_LOGIN_PSW" -X POST -H "Content-Type: multipart/form-data" --data-binary "@${deb_pkg}" "https://nexus3.ihtsdotools.org/repository/${rel_type}/")
                status=$(curl -o /dev/null --write-out '%{http_code}\n' -u "$NEXUS_LOGIN_USR:$NEXUS_LOGIN_PSW" -X POST -H "Content-Type: multipart/form-data" --data-binary "@${deb_pkg}" "https://nexus3.ihtsdotools.org/repository/${rel_type}/")
                echo "Status=${status}"

                if (( status > 299 )); then
                    exit 1
                else
                    echo "Upload successful"
                fi
            else
                echo "No debian package found to upload"
            fi
        else
            echo "No debian package built to upload"
        fi
    fi
}

echo "--------------------------------------"

case $SNOMED_PROJECT_BUILD_TOOL in
    maven)
        deployDebianPackages
        ;;
    gradle)
        ./gradlew uploadArchives
        ;;
    none)
        echo "No build tool required."
        ;;
    *)
        echo "Unknown build tool: ${SNOMED_PROJECT_BUILD_TOOL}"
        exit 1
        ;;
esac

echo "--------------------------------------"
