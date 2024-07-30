#!/usr/bin/env bash

echo "- - - - - - - - - - - - - - - - - - - - Password"
chpasswd <<<"root:password"

# Install any programs you need!
echo "- - - - - - - - - - - - - - - - - - - - Update"
apt-get update
echo "- - - - - - - - - - - - - - - - - - - - Git"
apt-get install -y git
echo "- - - - - - - - - - - - - - - - - - - - Maven"
apt-get install -y maven
echo "- - - - - - - - - - - - - - - - - - - - Graphviz"
apt-get install -y graphviz
echo "- - - - - - - - - - - - - - - - - - - - Gradle"
apt-get install -y gradle
echo "- - - - - - - - - - - - - - - - - - - - Groovy"
apt-get install -y groovy
echo "- - - - - - - - - - - - - - - - - - - - Doxygen"
apt-get install -y doxygen
echo "- - - - - - - - - - - - - - - - - - - - Curl and Wget"
apt-get install -y curl
apt-get install -y wget
echo "- - - - - - - - - - - - - - - - - - - - Commons CSV"
apt-get install -y libcommons-csv-java
apt-get install -y libopencsv-java
apt-get install -y libgroovycsv-java
echo "- - - - - - - - - - - - - - - - - - - - XML Lint"
apt-get install -y libxml2-utils
echo "- - - - - - - - - - - - - - - - - - - - Vim"
apt-get install -y vim
echo "- - - - - - - - - - - - - - - - - - - - xmlstarlet"
apt-get install -y xmlstaret
echo "- - - - - - - - - - - - - - - - - - - - Banners"
apt-get install -y figlet sysvbanner toilet
echo "- - - - - - - - - - - - - - - - - - - - Done"

# Set java 17 path.
ln -s /opt/java/openjdk/ /opt/jdk17

# Set path to emulate live.
ln -s /var/jenkins_home/ /var/lib/jenkins

# Install gitleaks.
if [[ ! -d /opt/gitleaks ]]; then
    mkdir -p /opt/gitleaks
    cd /opt/gitleaks || exit 1
    # If you want a newer version of gitleaks change this URL!
    wget https://github.com/gitleaks/gitleaks/releases/latest/download/gitleaks_8.18.4_linux_x64.tar.gz
    tar xvfz gitleaks_8.18.4_linux_x64.tar.gz
fi
