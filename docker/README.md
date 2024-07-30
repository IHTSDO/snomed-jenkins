<!-- TOC -->
* [Summary](#summary)
* [Jenkins configuration volume](#jenkins-configuration-volume)
* [Copy setup files from live jenkins](#copy-setup-files-from-live-jenkins)
* [Install live files locally](#install-live-files-locally)
* [Changes once the configuration is transferred—IMPORTANT](#changes-once-the-configuration-is-transferredimportant)
* [Build the image](#build-the-image)
* [Run the image](#run-the-image)
* [First login to your new local Jenkins machine.](#first-login-to-your-new-local-jenkins-machine)
* [Set timeout to 5 minutes](#set-timeout-to-5-minutes)
* [Clearing the queue](#clearing-the-queue)
* [Useful docker commands to manage your local install](#useful-docker-commands-to-manage-your-local-install)
* [Useful locations](#useful-locations)
* [Image snapshot](#image-snapshot)
* [Docker in docker](#docker-in-docker)
* [Sonar](#sonar)
  * [Other useful docker commands for Sonar](#other-useful-docker-commands-for-sonar)
<!-- TOC -->

# Summary

This folder contains all of the necessary files to create and run a local Docker instance of a Jenkins server.
The simplest way to ensure you get an EXACT setup of jenkins is to log onto the `live` box and copy key files.
How to do this is detailed below.

If you cannot ssh onto the box, you can get the zip files from someone else or ask DevOps for access.

Note one of the commands below will update the jenkins url to use localhost:8083.
This is necessary for safety reasons.
Also note that some of the scripts that run as part of the pipeline check for the machine hostname,
basically something's only happen if the hostname is the same as the production environment.
For example, webhooks are only configured if the machine is the production box.

Note this docker machine is a minimal installation of linux.
You can see the root password is at the start of the `config/scipt.sh` file which is run on installation.

The following steps will create a locally running jenkins server, which mirrors your production server.

# Jenkins configuration volume

To ease configuration these instructions use a shared volume.
This local folder is used to store all of the jenkins configuration,
and is shared with the docker image, via docker's volume mechanism.

Add the following to your .bashrc or .bash_profile:

```shell
export SNOMED_DATA=/Some/Location/On/Your/Computer
```

On my machine this setting is in my `~/.zshrc` file:

```shell
export SNOMED_DATA=${HOME}/Data
```

# Copy setup files from live jenkins

* First Check what is there, there might be an old back you want to use, and ignore the next step.

```shell
ssh jenkins "ls -l *.zip"
```

Make zips of key folders/files from live.

* Main config files

```shell
ssh jenkins "cd /var/lib/jenkins; zip ~/xml.zip *.xml"
```

* All the plugins
```shell
ssh jenkins "cd /var/lib/jenkins;zip -r ~/plugins.zip plugins"
```

* Images etc
```shell
ssh jenkins "cd /var/lib/jenkins;zip -r ~/userContent.zip userContent"
```

* Starter projects
```shell
ssh jenkins "cd /var/lib/jenkins;zip -r ~/jobClean.zip jobs/_CleanSpreadsheetCache_"
```
```shell
ssh jenkins "cd /var/lib/jenkins;zip -r ~/jobDaily.zip jobs/_DailyAnalysis_"
```
```shell
ssh jenkins "cd /var/lib/jenkins;zip -r ~/jobCreate.zip jobs/_PipelineCreationJob_"
```

* Copy zips locally

```shell
if [[ ! -d ${SNOMED_DATA}/jenkins_config ]]; then
  mkdir -p ${SNOMED_DATA}/jenkins_config
fi 
cd ${SNOMED_DATA}/jenkins_config || exit 1
rm *.zip
scp jenkins:xml.zip .
scp jenkins:userContent.zip .
scp jenkins:plugins.zip .
scp jenkins:jobClean.zip .
scp jenkins:jobDaily.zip .
scp jenkins:jobCreate.zip .
ls -l
```

* Cleanup zip files on Jenkins (optional)

```shell
ssh jenkins "rm *.zip"
```

# Install live files locally

* Make a folder for your local jenkins configuration, this will be a mounted volume on docker.

```shell
if [[ ! -d ${SNOMED_DATA}/jenkins_home ]]; then
  mkdir -p ${SNOMED_DATA}/jenkins_home
fi 
```

* Unzip configuration to `jenkins_home`

```shell
cd ${SNOMED_DATA}/jenkins_config
unzip xml.zip -d $SNOMED_DATA/jenkins_home/
unzip plugins.zip -d $SNOMED_DATA/jenkins_home/
unzip userContent.zip -d $SNOMED_DATA/jenkins_home/
unzip jobClean.zip -d $SNOMED_DATA/jenkins_home/
unzip jobDaily.zip -d $SNOMED_DATA/jenkins_home/
unzip jobCreate.zip -d $SNOMED_DATA/jenkins_home/
```

# Changes once the configuration is transferred—IMPORTANT

You now need to add this docker machine access to github in your personal github account see [GITHUB authentication](../README.md/#github-authentication)

From now on keep a safe copy of the `${SNOMED_DATA}/jenkins_home/.ssh` folder. If you rebuild the docker image, just copy this back and access will be restored.

* You have to change the URL in the config to point to your local machine:
```shell
sed -i 's/jenkinsUrl>http.*</jenkinsUrl>http:\/\/localhost:8083\/</' ${SNOMED_DATA}/jenkins_home/jenkins.model.JenkinsLocationConfiguration.xml
```

* Disable gitlab user login integration, there will just be one admin user on this Jenkins machine.
```shell
sed -i 's/useSecurity>true/useSecurity>false/' ${SNOMED_DATA}/jenkins_home/config.xml
```

* Change sonar to use local version.
```shell
sed -i 's/https:\/\/sonarqube.*org/http:\/\/172.17.0.1:9000/g' config.xml
sed -i 's/https:\/\/sonarqube.*org/http:\/\/172.17.0.1:9000/g' hudson.plugins.sidebar_link.SidebarLinkPlugin.xml
sed -i 's/https:\/\/sonarqube.*org/http:\/\/172.17.0.1:9000/g' hudson.plugins.sonar.SonarGlobalConfiguration.xml
```

Later you will start a sonar server and copy over its token so the jenkins and sonar machines talk to one another.

# Build the image

First use the [Dockerfile](Dockerfile) to setup a local image of Jenkins.

```shell
docker build -t jenkins .
```

# Run the image

* Once you have an image you can run it with the following:

```shell
docker run \
    -p 8083:8083 \
    -p 50001:50001 \
    --privileged \
    --restart=on-failure \
    --volume /var/run/docker.sock:/var/run/docker.sock \
    --volume $SNOMED_DATA/jenkins_home:/var/jenkins_home \
    --name JENKINS \
     jenkins
```

#  First login to your new local Jenkins machine.

The local url of jenkins will be [http://localhost:8083/](http://localhost:8083/).  On initial login you need to set a password:

* You will need initial password, which is in the log.
```shell
cat ${SNOMED_DATA}/jenkins_home/secrets/initialAdminPassword
```

* Then fill in the form and install all the recommended plugins.

* To restart the box: [http://localhost:8083/restart/](http://localhost:8083/restart/)

You are done. Below are some extra commands, which you might find useful.

# Set timeout to 5 minutes

Visit the [configure page](http://localhost:8083/manage/configure) and set the __Quiet period__ to 300 seconds.
This gives you plenty of time to stop any builds, if you do not want them to start automatically.

# Clearing the queue

You may see all projects start to build,
if you do go to the [script console](http://localhost:8083/manage/script) paste the following and run it.

```groovy
Jenkins.instance.queue.clear()
```

# Useful docker commands to manage your local install


* Start Jenkins

```shell
docker start JENKINS
```

* Stop Jenkins

```shell
docker stop JENKINS
```

* Remove your container

```shell
docker rm JENKINS
```

* Remove your image

```shell
docker rmi --force jenkins
```

* Login

```shell
docker exec -it JENKINS bash
```

# Useful locations

* List shared volume

```shell
ls -l $SNOMED_DATA/jenkins_home
```

* List workspaces on shared volume

```shell
ls -laR $SNOMED_DATA/jenkins_home/workspace
```

# Image snapshot

This allows you to save a known state to revert to if needed.

```shell
docker commit JENKINS jenkins_image:latest
```

# Docker in docker

If you have issues with running docker in the jenkins docker container [see this page](https://devopscube.com/run-docker-in-docker/)

* You may have to open the docker socket on the container with:

```shell
chmod 666 /var/run/docker.sock
```

# Sonar

[SonarQube](https://www.sonarsource.com) is used to monitor code quality 
here is an interesting article on [sonarqube](https://www.baeldung.com/sonar-qube)

* To start a sonar container you only need this command:

```shell
docker run \
    -d \
    --name SONARQUBE \
    -e SONAR_ES_BOOTSTRAP_CHECKS_DISABLE=true \
    -p 9000:9000 \
    sonarqube:latest
```

The container will be fully configured with the defaults and you will only have to copy the token to Jenkins.

* Its URL will be: http://localhost:9000/account
* Login with a username of __admin__ and password of __admin__.
* Then change the password to something you can remember, bear in mind this is not a secure machine.
* You will need to generate a token and place this in Jenkins [here](http://localhost:8083/manage/credentials/).

## Other useful docker commands for Sonar

* Stop SonarQube

```shell
docker stop SONARQUBE
```

* Remove your container

```shell
docker rm SONARQUBE
```

* Remove your image

```shell
docker rmi --force sonarqube
```

* Login

```shell
docker exec -it SONARQUBE bash
```
