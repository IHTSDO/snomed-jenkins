# Snomed Jenkins

Tooling for Jenkins build pipelines.

We use a Jenkins with minimal configuration,
most control is via the groovy and bash scripts contained within this project.
We have however installed some plugins and configured some environment variables.
Also we have installed some libraries on the linux box that Jenkins runs on.
All of this is documented below.

# Jenkins Configuration

## Jenkins Plugins

The following is a list of the plugins we use in our Jenkins instance.

* Theme
  *  http://afonsof.com/jenkins-material-theme/
  * https://devopscube.com/setup-custom-materialized-ui-theme-jenkins/#:~:text=Uploading%20Custom%20CSS%20TO%20Jenkins%20Server&text=Step%201%3A%20Login%20to%20your,layout%20inside%20the%20userContent%20directory.&text=Step%203%3A%20cd%20into%20the,css%20file.
  * Jenkins simple theme plugin
  * Set CSS TO this:
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
  * Dark Theme
  * Material Theme
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

## Jenkins Configuration

* Added environment variable to Jenkins

    SNOMED_SPREADSHEET_URL = https://docs.google.com/spreadsheets/d/13Hdd_hf1HbUAUVbMbzZgQPQIkQ_gI8rGZ9IS3WvK5iM

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
  * sudo tar -C /usr/local --strip-components 1 -xvf node-v20.9.0-linux-x64.tar.xz
* xfvb
* libgbm-dev

# GITHUB authentication

- Create of ed25519 SSH key pair

```bash
ssh-keygen -t ed25519
```

- Add public key to github
- Add private key to Jenkins credentials
- Then on command line as jenkins download a repo and accept the fingerprint, this will create a `known_hosts` file in the `.ssh` directory.
