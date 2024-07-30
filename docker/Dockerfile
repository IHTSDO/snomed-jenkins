FROM jenkins/jenkins:lts-jdk17

# See: https://hub.docker.com/r/jenkins/jenkins
# https://github.com/jenkinsci/docker/

# Set root password and install a bunch of useful tools.
COPY --chown=jenkins:jenkins config/script.sh /tmp/script.sh
USER root
RUN chmod 775 /tmp/script.sh
RUN /tmp/script.sh
USER jenkins

COPY --chown=jenkins:jenkins config/openCsp.groovy   /usr/share/jenkins/ref/init.groovy.d/openCsp.groovy
COPY --chown=jenkins:jenkins config/executors.groovy /usr/share/jenkins/ref/init.groovy.d/executors.groovy

ENV JENKINS_OPTS --httpPort=8083 --argumentsRealm.roles.user=admin --argumentsRealm.passwd.admin=admin --argumentsRealm.roles.admin=admin
ENV JENKINS_SLAVE_AGENT_PORT 50001

EXPOSE 8083
