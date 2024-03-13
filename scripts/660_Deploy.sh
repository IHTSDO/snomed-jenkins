#!/usr/bin/env bash
source "$SCRIPTS_PATH/000_Config.sh"
figlet -w 500 "Deploy to Nexus"

# TODO: https://github.com/docker/docker-credential-helpers#available-programs
deployToDockerHub() {
    if [[ $GIT_BRANCH == "master" ]] || [[ $GIT_BRANCH == "main" ]]; then
        containsJib=$((xmllint --xpath '/*[local-name()="project"]/*[local-name()="build"]/*[local-name()="plugins"]/*[local-name()="plugin"]/*[local-name()="artifactId"]' pom.xml 2>&1|| true) | (grep -c jib-maven-plugin || true))

        if ((containsJib == 1)); then
            figlet -w 500 "Docker Hub"
            echo "Maven JIB configuration and on $GIT_BRANCH so deploying to DOCKERHUB"
            echo "$DOCKER_HUB_PSW" | docker login -u "$DOCKER_HUB_USR" --password-stdin
            mvn jib:build
            echo "Docker hub deployment completed"
        fi
    fi
}

performMavenDeployments() {
    echo "Uploading debian package to Nexus"
    local release_area="NONE"

    if [[ $GIT_BRANCH == "master" ]] || [[ $GIT_BRANCH == "main" ]] || [[ $GIT_BRANCH == "release-candidate" ]]; then
        release_area="releases"
    elif [[ $GIT_BRANCH == "develop" ]] || [[ $GIT_BRANCH =~ nexus$ ]]; then
        release_area="snapshots"
    else
        echo "NOT uploading to Nexus:"
        echo "    'main/master' branch is uploaded to Nexus in 'debian-releases'"
        echo "    'develop' and branches ending in 'nexus' are uploaded to Nexus in 'debian-snapshots'"
    fi

    if [[ $release_area != "NONE" ]]; then
        if [[ $HOST =~ prod-jenkins* ]]; then
            echo "Deploy to maven-${release_area}."
            mvn deploy -U -Dmaven.test.skip=true -Ddependency-check.skip=true \
                -DaltDeploymentRepository=ihtsdo-public-nexus::default::https://nexus3.ihtsdotools.org/repository/maven-${release_area}/
        else
            echo "Can only deploy to nexus from prod-jenkins"
        fi

        echo "Build the debian package debian-${release_area}."
        mvn install -Pdeb -Dmaven.test.skip=true -Ddependency-check.skip=true
        # Is it there?
        deb_pkg_count=$(find . -name "*.deb" -print -quit | wc -l)

        if ((deb_pkg_count > 0)); then
            echo "Deployable package exists"
            deb_pkg=$(find . -name "*.deb" -print -quit)

            if [[ -e ${deb_pkg} ]]; then
                echo "File to upload is: ${deb_pkg}"

                # See example 7 here: https://www.jenkins.io/doc/book/pipeline/syntax/#environment
                echo "curl -s -o /dev/null --write-out '%{http_code}\n' -u \"NEXUS_LOGIN_USR:NEXUS_LOGIN_PSW\" -X POST -H \"Content-Type: multipart/form-data\" --data-binary \"@${deb_pkg}\" \"https://nexus3.ihtsdotools.org/repository/debian-${release_area}/\""

                if [[ $HOST =~ prod-jenkins* ]]; then
                    status=$(curl -s -o /dev/null --write-out '%{http_code}\n' -u "$NEXUS_LOGIN_USR:$NEXUS_LOGIN_PSW" -X POST -H "Content-Type: multipart/form-data" --data-binary "@${deb_pkg}" "https://nexus3.ihtsdotools.org/repository/debian-${release_area}/")
                    echo "Check: https://nexus3.ihtsdotools.org/#browse/browse:debian-${release_area}:packages%2F${SNOMED_PROJECT_NAME:0:1}%2F${SNOMED_PROJECT_NAME}"
                    echo "Curl return status=${status}"
                    figlet -w 500 "${status}"

                    case $status in
                        200) echo "200 - OK." ;;
                        201) echo "201 - Upload was successful." ;;
                        400) echo "400 - Is the build version already deployed on Nexus, increment the project version?" ;;
                        401) echo "401 - Unauthorised, username and/or password is incorrect." ;;
                        403) echo "403 - Forbidden no have access rights to the content.  Unlike 401 Unauthorized, the client's identity is known to the server." ;;
                        404) echo "404 - Not found, wrong upload location?" ;;
                        *) echo "${status} - Some other status, see: https://developer.mozilla.org/en-US/docs/Web/HTTP/Status" ;;
                    esac

                    if ((status > 299)); then
                        exit 1
                    else
                        echo "Upload successful"
                    fi
                else
                    echo "Can only deploy to nexus from prod-jenkins"
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

if [[ $SNOMED_PROJECT_DEPLOY_ENABLED == TRUE ]]; then
    case $SNOMED_PROJECT_LANGUAGE in
        Cypress | Typescript | Javascript)
            performMavenDeployments
            ;;
        *)
            case $SNOMED_PROJECT_BUILD_TOOL in
                maven)
                    performMavenDeployments
                    deployToDockerHub
                    ;;
                gradle)
                    ./gradlew uploadArchives
                    ;;
                none)
                    echo "No deploy tool required."
                    ;;
                *)
                    echo "Unknown build tool: ${SNOMED_PROJECT_BUILD_TOOL}"
                    exit 1
                    ;;
            esac
            ;;
    esac
else
    echo Deployment disabled for the project.
fi

echo "--------------------------------------"
