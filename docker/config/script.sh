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
apt-get install -y xmlstarlet
echo "- - - - - - - - - - - - - - - - - - - - Banners"
apt-get install -y figlet sysvbanner toilet

echo "---------------"
echo "- For Cypress -"
echo "---------------"
echo "- - - - - - - - - - - - - - - - - - - - libatk"
#ATK (Accessible Toolkit) is an open source library that provides a set of interfaces for accessibility.
#It's an integral part of GTK, the GIMP Toolkit, but can also be used in other types of applications on
#Linux/Unix platforms.
#It gives applications the ability to provide more information about their user interface in a generic way,
#so that assistive technologies can make use of it. It primarily aids in accessibility for people with
#disabilities. For instance, screen readers use ATK to interpret the GUI of an application.
#Cypress uses it for testing.
apt-get install -y libatk1.0-dev \
                   libatk-bridge2.0-dev \
                   libgtk-3-0
echo "- - - - - - - - - - - - - - - - - - - - npm"
# Node Package Manager, a popular package manager for JavaScript.  Used by cypress projects.
apt-get install -y npm

echo "- - - - - - - - - - - - - - - - - - - - xvfb"
#X virtual framebuffer, is a display server implementing the X11 display server protocol. It operates entirely in
#memory without the need for a physical display. Xvfb doesn't do any graphics operations or hardware acceleration,
#making it perfect for use in headless server environments.  i.e. testing on jenkins.....
#Xvfb is typically used to run tests for graphical applications which don't need to be displayed and can be checked
#for correctness with other means. For instance, you might have an application that will be ultimately deployed on
#a machine with an X server but you want to test it on a regular, non-graphical server.
#With Xvfb, you can run these applications and have them believe they're on a machine with a display, when in actuality
#they're interacting with Xvfb. It's often used for automated testing of GUI applications or for creating screencasts.
apt-get install -y xvfb
echo "- - - - - - - - - - - - - - - - - - - - Done"

echo "- - - Set java 17 path."
# live jenkins has java installed in different location this soft link mimics this on docker instance.
ln -s /opt/java/openjdk/ /opt/jdk17

echo "- - - Set path to emulate live."
# live jenkins is installed in different location this soft link mimics this on docker instance.
ln -s /var/jenkins_home/ /var/lib/jenkins

if [[ ! -d /opt/gitleaks ]]; then
    echo "- - - Install gitleaks."
    mkdir -p /opt/gitleaks
    cd /opt/gitleaks || exit 1
    # If you want a newer version of gitleaks change the following two lines.
    wget https://github.com/gitleaks/gitleaks/releases/download/v8.18.4/gitleaks_8.18.4_linux_x64.tar.gz
    tar xvfz gitleaks_8.18.4_linux_x64.tar.gz
fi
