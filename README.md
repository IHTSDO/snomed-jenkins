# Snomed Jenkins

This project contains all code for the Jenkins build pipelines for Snomed CT, with the following exception:

The builds are controlled by **pipelines**:
* their code is here: https://dev-jenkins.ihtsdotools.org/manage/configfiles/
* The main build pipeline is SnomedPipeline_Maven_jdk17 which sets up maven/gradle and Java17.
* The other pipeline is for Cypress builds, this is likely to change.

We use a Jenkins with minimal bespoke/non-standard configuration,
most control is via the groovy and bash scripts contained within this project.
We have however installed some plugins and configured some environment variables.
Also we have installed some libraries on the linux box that Jenkins runs on.
All of this is documented below.

# Primary spreadsheet

The primary spreadsheet controls, which jobs are built and how. It is located here:

* https://docs.google.com/spreadsheets/d/13Hdd_hf1HbUAUVbMbzZgQPQIkQ_gI8rGZ9IS3WvK5iM

# Jobs

Jenkins contains two jobs; all others are automatically created by the scripts in this project,
which is controlled by the primary spreadsheet.

The two jobs are:
(Note the job names start with an underscore, this allows for easy identification and auto-management.)

## \_DailyAnalysis\_ job
This runs the following, every morning:

```shell
# Search for CVE's in project reports and generate tsv file.
../_PipelineCreationJob_/jobMakeCveTable.sh tsv

# Analyse project pom.xml files and generate PNG and SVG images.
../_PipelineCreationJob_/jobMakeDependencyGraph.sh

# Create new Jira tickets if required.
../_PipelineCreationJob_/createCveJiraTickets.sh

# Use TSV file and existing Jira tickets to create HTML report.
../_PipelineCreationJob_/jobMakeCveTable.sh html
```

## \_PipelineCreationJob\_ job
This runs:
```shell
jobMake.groovy
approveAllScripts.groovy
```

# Pipelines.

As mentioned above, the builds are controlled by several mechanisms working together:

* Pipelines
* Groovy scripts
* Shell scripts

I've tried to keep the use of groovy to a minimum, all build steps are bash scripts.
All of the Groovy and Shell scripts are located in this project in the `jobs/_PipelineCreationJob_` folder.

* Shell scripts starting with a number are called from the pipelines roughly in numerical order.
  - `000_Config.sh` is used by all of the pipeline scripts to download and use the primary spreadsheet to populate environment variavblesthe 
* The remaining shell scripts are part of the nightly build process.
* The groovy scripts are all part of the control of Jenkins using groovy and the DSL: https://plugins.jenkins.io/job-dsl/

# Jenkins Configuration

## Jenkins Plugins

The following is a list of the plugins we use in our Jenkins instance.

* Theme
  - http://afonsof.com/jenkins-material-theme/
  - https://devopscube.com/setup-custom-materialized-ui-theme-jenkins/#:~:text=Uploading%20Custom%20CSS%20TO%20Jenkins%20Server&text=Step%201%3A%20Login%20to%20your,layout%20inside%20the%20userContent%20directory.&text=Step%203%3A%20cd%20into%20the,css%20file.
  - Jenkins simple theme plugin
  - Set CSS TO this:
```css
.logo img {
    content:url(/userContent/layout/logo.png);
}
#jenkins-name-icon {
    display: none;
}
.logo:after {
    content: 'Snomed Jenkins Dev Server';
    font-size: 35px;
    font-family: Arial, Helvetica, sans-serif;
    margin-left: 20px;
    margin-right: 12px;
    line-height: 40px;
}
```
  - Dark Theme
  - Material Theme
* AnsiColor
* Ant
* Config file provider
* Doxygen
* Gradle
* Groovy
* HTML Publisher
* JaCoCo
* Job DSL
* Maven Integration
* OWASP Dependency-Check
* Pipeline
* Dashboard ViewVersion
* Multibranch Scan Webhook Trigger

## Jenkins Configuration

* Added environment variable to Jenkins, here: https://dev-jenkins.ihtsdotools.org/manage/configure

```properties
SNOMED_SPREADSHEET_URL = https://docs.google.com/spreadsheets/d/13Hdd_hf1HbUAUVbMbzZgQPQIkQ_gI8rGZ9IS3WvK5iM
```

## Credentials:

* These are all setup here: https://dev-jenkins.ihtsdotools.org/manage/credentials/
* You can see in the pipelines how these are passed.....

## Linux box libraries installed:

* JDK11
* JDK13
* JDK17
* doxygen
* figlet
* graphviz
* dot
* bc
* xmlstarlet
* xmllint (installed in libxml2-utils)
* nodejs, npm and npx with:
  - sudo tar -C /usr/local --strip-components 1 -xvf node-v20.9.0-linux-x64.tar.xz
* xfvb
* libgbm-dev

# GITHUB authentication

* Create of ed25519 SSH key pair

```bash
ssh-keygen -t ed25519
```

* Add public key to github
* Add private key to Jenkins credentials
* Then on command line as jenkins download a repo and accept the fingerprint, this will create a `known_hosts` file in the `.ssh` directory.
