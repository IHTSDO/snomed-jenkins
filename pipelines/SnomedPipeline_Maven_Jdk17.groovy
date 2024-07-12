pipeline {
    agent any

    tools {
        jdk 'jdk17'
        maven 'Maven'
        gradle 'gradle'
    }

    options {
        ansiColor('css')
        buildDiscarder logRotator(daysToKeepStr: '5', numToKeepStr: '5')
    }

    stages {
        stage('Initialise') {
            steps {
                cleanWs()
                sh '../_PipelineCreationJob_/scripts/010_Initialize.sh'
            }
        }

        stage('Code Checkout') {
            steps {
                checkout([
                        $class           : 'GitSCM',
                        branches         : [[name: "${GIT_BRANCH}"]],
                        userRemoteConfigs: [[url: "${GIT_URL}"]]
                ])
            }
        }

        stage('Sanity Check') { steps { sh "../_PipelineCreationJob_/scripts/020_SanityCheck.sh" } }
        stage('Build') { steps { sh "../_PipelineCreationJob_/scripts/500_Build.sh" } }
        stage('Test') { steps { sh "../_PipelineCreationJob_/scripts/510_Test.sh" } }

        stage('Security') {
            when {
                anyOf {
                    branch 'main'
                    branch 'master'
                    branch 'develop'
                    branch 'release-candidate'
                }
            }
            steps {
                sh "../_PipelineCreationJob_/scripts/600_Security.sh || true" }
            post {
                success {
                    dependencyCheckPublisher(stopBuild: false)
                }
            }
        }

        stage('Documentation') {
            when {
                anyOf {
                    branch 'main'
                    branch 'master'
                }
            }
            steps { sh "../_PipelineCreationJob_/scripts/610_Documentation.sh || true" }
            post {
                success {
                    publishHTML(target: [
                            allowMissing          : false,
                            alwaysLinkToLastBuild : true,
                            keepAll               : false,
                            reportDir             : 'target/html',
                            reportFiles           : 'index.html',
                            reportName            : 'Javadoc',
                            reportTitles          : ''
                    ])
                }
            }
        }

        stage('Performance') {
            when {
                anyOf {
                    branch 'main'
                    branch 'master'
                    branch 'develop'
                    branch 'release-candidate'
                }
            }
            steps { sh "../_PipelineCreationJob_/scripts/620_Performance.sh" }
        }
        stage('Quality') {
            when {
                anyOf {
                    branch 'main'
                    branch 'master'
                    branch 'develop'
                    branch 'release-candidate'
                }
            }
            steps { sh "../_PipelineCreationJob_/scripts/630_Quality.sh" }
        }
        stage('Audit') {
            when {
                anyOf {
                    branch 'develop'
                }
            }
            environment {
                SONAR_TOKEN = credentials('SONAR_TOKEN')
            }
            steps { sh "../_PipelineCreationJob_/scripts/650_Audit.sh" }
        }
        stage('Deploy') {
            environment {
                // Use ID from credentials.
                NEXUS_LOGIN = credentials('jenkins')
                DOCKER_HUB = credentials('DOCKER_HUB')
            }
            when {
                anyOf {
                    branch 'main'
                    branch 'master'
                    branch 'develop'
                    branch 'release-candidate'
                }
            }
            steps { sh "../_PipelineCreationJob_/scripts/660_Deploy.sh" }
        }
        stage('Build Downstream Projects') {
            environment {
                BUILD_TRIGGER = credentials('BUILD_TRIGGER')
            }
            steps { sh "../_PipelineCreationJob_/scripts/800_TriggerDownstream.sh" }
        }
    }

    environment {
        SLACK_TOKEN = credentials('SLACK_CREDS')
        SLACK_CHANNEL_SUCCESS = """${sh( returnStdout: true, script: "../_PipelineCreationJob_/scripts/950_SelectCommsChannel.sh success" )}"""
        SLACK_CHANNEL_FAILURE = """${sh( returnStdout: true, script: "../_PipelineCreationJob_/scripts/950_SelectCommsChannel.sh failure" )}"""
        EMAIL_LIST = """${sh( returnStdout: true, script: "../_PipelineCreationJob_/scripts/950_SelectCommsChannel.sh email" )}"""
    }

    post {
        always {
            echo "Always"
            //junit 'target/surefire-reports/**/*.xml'
            jacoco(
                    execPattern: 'target/*.exec',
                    classPattern: 'target/classes',
                    sourcePattern: 'src/main/java',
                    exclusionPattern: 'src/test*'
            )
        }

        failure {
            echo "Failure slack message to: ${SLACK_CHANNEL_FAILURE}"
            slackSend channel: "${SLACK_CHANNEL_FAILURE}", color: 'danger', notifyCommitters: true, message: "Build failed '${env.JOB_NAME}' Branch:${env.BRANCH_NAME} Build${env.BUILD_DISPLAY_NAME} (<${env.BUILD_URL}|Open>)"

            script {
                if (EMAIL_LIST.equals("#")) {
                    echo "Emailing: culprits and requestor"
                    emailext(
                            recipientProviders: [culprits(), requestor()],
                            subject: "BUILD FAILURE: ${env.JOB_NAME} - ${currentBuild.displayName}",
                            body: """BUILD FAILURE:
${env.BUILD_URL}
"""
                    )
                } else {
                    echo "Emailing: ${EMAIL_LIST}, culprits and requestor"
                    emailext(
                            to: "${EMAIL_LIST}",
                            recipientProviders: [culprits(), requestor()],
                            subject: "BUILD FAILURE: ${env.JOB_NAME} - ${currentBuild.displayName}",
                            body: """BUILD FAILURE:
${env.BUILD_URL}
"""
                    )
                }
            }
        }
    }
}
