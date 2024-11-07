@Grab('com.xlson.groovycsv:groovycsv:1.3')
import com.xlson.groovycsv.CsvParser
import jenkins.model.Jenkins
import java.security.MessageDigest
import java.net.InetAddress

// Note on pipelines vs freestyle projects:
//    - Freestyle are in folders, pipelines are not, see ~/workspace/cve
//    - Pipelines cannot accept cron so cannot easily be scheduled.
//    - Freestyle you do not see a nice pipeline in the GUI :-(

def envVars = Jenkins.instance.getGlobalNodeProperties()[0].getEnvVars()

BASEFOLDER = "/tmp/"
SPREADSHEET_FILE_NAME = "${BASEFOLDER}ProjectsDSL.csv"
SPREADSHEET_URL = envVars["SNOMED_SPREADSHEET_URL"]
SNOMED_TOOLS_URL = envVars["SNOMED_TOOLS_URL"]
SPREADSHEET = "${SPREADSHEET_URL}/gviz/tq?tqx=out:csv"
DOWNLOAD = true

// Spreadsheet column names.
COLUMN_JENKINS_BUILD_ENABLED = "Jenkins Build Enabled"
COLUMN_PROJECT_NAME = "Project Name"
COLUMN_GROUP_ARTIFACT = "GroupId:ArtifactID"
COLUMN_BUILD_TOOL = "Build Tool"
COLUMN_LANGUAGE = "Language"
COLUMN_PROJECT_TYPE = "Project Type"
COLUMN_JENKINS_DEPLOY_ENABLED = "Deploy Enabled"
COLUMN_JENKINS_DEPLOY_CONFIG = "Deploy Config"
COLUMN_SLACK_CHANNEL = "Slack Channel"
COLUMN_NOTIFIED_USERS = "Notified Users"
COLUMN_USES_BOM = "Uses BOM?"
COLUMN_SNOMED_DEPENDENCIES = "Snomed Dependencies"
COLUMN_OWNER = "Owner"
COLUMN_NOTES = "Notes"

FOLDER_JOBS='jobs'
FOLDER_CVE='cve'
FOLDER_E2E='e2e'
FOLDER_E2E_UAT='e2euat'

enum JobTypes {cve, e2eDev, e2eUat}

//NUMBER_OF_JOBS_TO_KEEP = 5
//NUMBER_OF_DAYS_TO_KEEP = 5
NUMBER_OF_NIGHTLY_JOBS_TO_KEEP = 5
BANNER_MESSAGE = "Automated build pipeline job, if you edit this pipeline your changes will be lost on next system startup."
GIT_HUB_CREDENTIALS_ID = '375fc783-9b0d-48be-a251-af24d82922bb'

String hostname = InetAddress.getLocalHost().getHostName()
onProd=hostname.equalsIgnoreCase("prod-jenkins." + SNOMED_TOOLS_URL)
println "Hostname : ${hostname} (Prod?=${onProd})"

File spreadsheet = new File(SPREADSHEET_FILE_NAME)
println "Reading ${SPREADSHEET_FILE_NAME}"
downloadSpreadsheet(spreadsheet)
makeFolders()

PRJ_FILE = new File('/tmp/prj_list.txt')
println "Project list to ${PRJ_FILE.getAbsolutePath()}"
PRJ_FILE.write("")

if (onProd) {
    println "On production"
    HOOK_FILE = new File('hook_list.txt')
    HOOK_FILE.write("")
    NIGHTLY_TRIGGER_CVE = "H 5 * * 1-5"
    NIGHTLY_TRIGGER_E2E = "H H(6-8) * * 1-5"
    MANUAL_TRIGGER_E2E = ""
} else {
    println "NOT on production"
    NIGHTLY_TRIGGER_CVE = ""
    NIGHTLY_TRIGGER_E2E = ""
    MANUAL_TRIGGER_E2E = ""
}

spreadsheet.withReader { reader ->
    int noOfProjects = 0
    int noOfEnabledOfProjects = 0
    java.util.LinkedHashMap projectsEnabled = [:]
    def rows = new CsvParser().parse(reader, autoDetect: true)

    for (row in rows) {
        noOfProjects++
        def projectIsEnabled = row."${COLUMN_JENKINS_BUILD_ENABLED}".toBoolean()

        if (projectIsEnabled) {
            def projectName = row."${COLUMN_PROJECT_NAME}".toLowerCase().find(/^([^\/]+)/)

            if (projectsEnabled[projectName]) {
                println "    - Skipping project ${projectName}"
                continue
            }

            projectsEnabled[projectName] = 1
            noOfEnabledOfProjects++
            makeJobs(projectName, row)
        }
    }

    println "Number of projects created: ${noOfEnabledOfProjects}/${noOfProjects}"
}

PRJ_FILE.append("END OF PROJECT LIST\n")

private void downloadSpreadsheet(File spreadsheet) {
    if (!DOWNLOAD && spreadsheet.exists()) {
        return
    }

    if (spreadsheet.exists()) {
        println "Removing old snomed code estate spreadsheet ${SPREADSHEET_FILE_NAME}"
        spreadsheet.delete()
    }

    println "Downloading snomed code estate spreadsheet from ${SPREADSHEET}"
    "curl --silent --output ${SPREADSHEET_FILE_NAME} ${SPREADSHEET}".execute()
    int attemptNumber = 0

    while (!spreadsheet.exists()) {
        attemptNumber++
        println "Downloading...[" + attemptNumber + "]"
        sleep(250)

        if (attemptNumber >= 100) {
            break
        }
    }
}

void makeFolders() {
    folder(FOLDER_JOBS) {
        displayName('Normal builds of All branches, triggered by github push')
        description("""
<div style="border-radius:25px;border:5px solid gray;padding:10px;background:#07AAE0;">
    <font style="color:white;font-size:30px;">Normal Build Jobs - Each job contains all active branches</font><br/>
    <font style="font-family:'Courier New';color:black;font-size:20px;">
       <a href="${SPREADSHEET_URL}"><font style="color:white;">Spreadsheet</font></a>
    </font>
</div>
""")
    }

    folder(FOLDER_CVE) {
        displayName('Nightly Builds of Develop CVE')
        description("""
<div style="border-radius:25px;border:5px solid gray;padding:10px;background:#07AAE0;">
    <font style="color:white;font-size:30px;">Nightly Builds - Develop is built every night to check for CVE/security issues</font><br/>
    <font style="font-family:'Courier New';color:black;font-size:20px;">
       <a href="${SPREADSHEET_URL}"><font style="color:white;">Spreadsheet</font></a>
    </font>
</div>
""")
    }

    folder(FOLDER_E2E) {
        displayName('Nightly Builds of Develop E2E')
        description("""
<div style="border-radius:25px;border:5px solid gray;padding:10px;background:#07AAE0;">
    <font style="color:white;font-size:30px;">Nightly Builds - Develop is built every night to run Cypress E2E tests</font><br/>
    <font style="font-family:'Courier New';color:black;font-size:20px;">
       <a href="${SPREADSHEET_URL}"><font style="color:white;">Spreadsheet</font></a>
    </font>
</div>
""")
    }

    folder(FOLDER_E2E_UAT) {
        displayName('Manual Builds of Main/Master E2E')
        description("""
<div style="border-radius:25px;border:5px solid gray;padding:10px;background:#07AAE0;">
    <font style="color:white;font-size:30px;">Manual Builds - Main/Master is built on demand to Cypress E2E tests</font><br/>
    <font style="font-family:'Courier New';color:black;font-size:20px;">
       <a href="${SPREADSHEET_URL}"><font style="color:white;">Spreadsheet</font></a>
    </font>
</div>
""")
    }
}

void makeJobs(String projectName, def row) {
    String projectGroupArtifact = row."${COLUMN_GROUP_ARTIFACT}"
    String projectBuildTool = row."${COLUMN_BUILD_TOOL}".toLowerCase().capitalize()
    String projectLanguage = row."${COLUMN_LANGUAGE}".toLowerCase().capitalize()
    String projectPipeLineType = new String("${projectBuildTool}_${projectLanguage}")
    String projectType = row."${COLUMN_PROJECT_TYPE}".toLowerCase()
    String projectSlackChannel = row."${COLUMN_SLACK_CHANNEL}".toLowerCase()
    String projectNotifiedUsers = row."${COLUMN_NOTIFIED_USERS}".toLowerCase()
    Boolean projectUsesBom = row."${COLUMN_USES_BOM}".toBoolean()
    String projectDependencies = row."${COLUMN_SNOMED_DEPENDENCIES}"
    String projectOwner = row."${COLUMN_OWNER}"
    String projectNotes = row."${COLUMN_NOTES}"
    String projectSrcUrl = new String("https://github.com/IHTSDO/${projectName}")
    String projectGitUri = new String("git@github.com:IHTSDO/${projectName}.git")
    String projectNexusUrl = new String("https://nexus3.${SNOMED_TOOLS_URL}/#browse/browse:debian-snapshots:packages%2Fs%2F${projectGroupArtifact}")
    String cveTableUrl = "/userContent/cveTable.html"
    // This needs to be constant so cannot be a UUID!
    String nameMd5Token = MessageDigest.getInstance("SHA256").digest(projectName.bytes).encodeHex().toString()
    String description = new String(generateDescription(projectName, projectSrcUrl, projectNexusUrl, projectGroupArtifact, projectBuildTool, projectLanguage, projectType, projectSlackChannel, projectNotifiedUsers, projectUsesBom, projectDependencies, projectOwner, projectNotes, cveTableUrl))

    println "Creating build pipeline : ${projectName} [ ${projectPipeLineType} ]"

    // Write information needed to make hooks in github.
    if (onProd) {
        HOOK_FILE.append("${nameMd5Token} ${projectName}\n")
    }

    PRJ_FILE.append("${FOLDER_JOBS}/${projectName}\n")

    // Full pipelines for majority of branches.
    if (projectType.equalsIgnoreCase("bom")) {
        generatePipeline(FOLDER_JOBS, projectType, "", "", nameMd5Token, projectGitUri, projectName,  description, projectBuildTool, projectLanguage)
    } else {
        generatePipeline(FOLDER_JOBS, "", "", "", nameMd5Token, projectGitUri, projectName,  description, projectBuildTool, projectLanguage)
    }

    // Setup Nightly Security jobs.
    if (!projectLanguage.toLowerCase().startsWith("jdk") || projectType.equalsIgnoreCase("bom")) {
        println "    SKIPPING: cve job for ${projectName} [ ${projectPipeLineType} ]"
    } else {
        generateFreestyle(JobTypes.cve, projectGitUri, projectName,  description, projectBuildTool, projectLanguage, projectSlackChannel, projectNotifiedUsers)
        PRJ_FILE.append("${FOLDER_CVE}/${projectName}\n")
    }

    // Setup E2E jobs.
    if (projectLanguage.equalsIgnoreCase("javascript") || projectLanguage.equalsIgnoreCase("typescript")) {
        generateFreestyle(JobTypes.e2eDev, projectGitUri, projectName, description,  projectBuildTool, projectLanguage, projectSlackChannel, projectNotifiedUsers)
        PRJ_FILE.append("${FOLDER_E2E}/${projectName}\n")
        generateFreestyle(JobTypes.e2eUat, projectGitUri, projectName, description,  projectBuildTool, projectLanguage, projectSlackChannel, projectNotifiedUsers)
        PRJ_FILE.append("${FOLDER_E2E_UAT}/${projectName}\n")
    } else {
        println "    SKIPPING: e2e / ${projectName} [ ${projectPipeLineType} ]"
    }
}

String generatePipeline(String folder, String suffix, String includeBranches, String cronExpression, String md5Token, String projectGitUri, String projectName, String desc, String projectBuildTool, String projectLanguage) {
    // JCO: Maven pipeline includes all gradle config, so use that!
    if (projectBuildTool == 'Gradle') {
        projectBuildTool='Maven'
    }

    // JCO: Javascript follows same pipeline as Typescript.
    if (projectLanguage == 'Javascript') {
        projectLanguage='Typescript'
    }

    String projectPipeLineType = new String("${projectBuildTool}_${projectLanguage}")
    println "    CREATING: ${folder} / ${projectName} (cron='${cronExpression}') (pipeline=${projectPipeLineType})"

    // https://jenkinsci.github.io/job-dsl-plugin/#path/multibranchPipelineJob
    multibranchPipelineJob("${folder}/${projectName}") {
        displayName("${projectName}")
        description(desc)

        branchSources {
            git {
                id(projectName)
                remote(projectGitUri)
                includes(includeBranches)
                excludes("")
            }
        }

        orphanedItemStrategy { discardOldItems {} }

        if (onProd && cronExpression) {
            println "        Adding cron : ${cronExpression}"
            triggers { cron(cronExpression) }
        }

        factory {
            pipelineBranchDefaultsProjectFactory {
                scriptId("SnomedPipeline_${projectPipeLineType}${suffix}")
                useSandbox(true)
            }
        }

        if (md5Token && onProd) {
            println "        Updating XML for MD5"
            // There is no DSL API hook for the https://plugins.jenkins.io/multibranch-scan-webhook-trigger/
            // so we need to use the XML configure hook to configure.
            // https://jenkinsci.github.io/job-dsl-plugin/#path/multibranchPipelineJob-configure
            // From this tutorial: https://medium.com/@maksymgrebenets/jenkins-job-dsl-configure-block-4a51aa891f7
            configure { node ->
                node / 'triggers' << 'com.igalg.jenkins.plugins.mswt.trigger.ComputedFolderWebHookTrigger' {
                    spec ''
                    token md5Token
                }
            }
        }
    }
}

String generateFreestyle(JobTypes jobType, String projectGitUri, String projectName, String desc, String projectBuildTool, String projectLanguage, String projectSlackChannel, String projectNotifiedUsers) {
    String includeBranches
    String folder
    String suffix
    String cronExpression
    String slackSubject
    GString commandStr

    switch (jobType) {
        case JobTypes.cve:
            includeBranches = "develop"
            folder = FOLDER_CVE
            suffix = "_CVE"
            cronExpression = NIGHTLY_TRIGGER_CVE
            slackSubject = "Security CVE test"
            commandStr = """$SCRIPTS_PATH/010_Initialize.sh
$SCRIPTS_PATH/020_SanityCheck.sh
$SCRIPTS_PATH/600_Security.sh"""
            println "    CREATING: ${folder} / ${projectName} (cron='${cronExpression}')"
            break
        case JobTypes.e2eDev:
            includeBranches = "develop"
            folder = FOLDER_E2E
            suffix = "_E2E"
            cronExpression = NIGHTLY_TRIGGER_E2E
            slackSubject = "E2E testing Dev"
            commandStr = """$SCRIPTS_PATH/010_Initialize.sh
$SCRIPTS_PATH/020_SanityCheck.sh
$SCRIPTS_PATH/500_Build.sh
$SCRIPTS_PATH/640_EndToEndTest.sh"""
            println "    CREATING: ${folder} / ${projectName} (cron='${cronExpression}')"
            break
        case JobTypes.e2eUat:
            includeBranches = "master,main"
            folder = FOLDER_E2E_UAT
            suffix = "_E2E_MAIN"
            cronExpression = MANUAL_TRIGGER_E2E
            slackSubject = "E2E testing UAT"
            commandStr = """$SCRIPTS_PATH/010_Initialize.sh
$SCRIPTS_PATH/020_SanityCheck.sh
$SCRIPTS_PATH/500_Build.sh
$SCRIPTS_PATH/640_EndToEndTest.sh"""
            println "    CREATING: ${folder} / ${projectName} (Manual)"
            break
    }

    // https://jenkinsci.github.io/job-dsl-plugin/#path/freeStyleJob
    freeStyleJob("${folder}/${projectName}") {
        displayName("${projectName}${suffix}")
        description(desc)
        jdk('jdk17')

        scm {
            git {
                remote {
                    github("IHTSDO/${projectName}", 'ssh')
                    credentials(GIT_HUB_CREDENTIALS_ID)
                }
                branches(includeBranches.split(','))
            }
        }

        if (onProd && cronExpression) {
            println "        Adding cron : ${cronExpression}"
            triggers { cron(cronExpression) }
        }

        logRotator(-1, NUMBER_OF_NIGHTLY_JOBS_TO_KEEP)
        wrappers {
            ansiColorBuildWrapper { colorMapName('xterm') }
            credentialsBinding {
                usernamePassword('TEST_LOGIN_USR','TEST_LOGIN_PSW', 'test-account-details')
            }
        }

        steps {
            shell {
                command(commandStr)
                // Maven returns 1 on build failure, interpret this as unstable, which means the report is ALWAYS generated/published.
                unstableReturn(1)
            }
        }

        publishers {
            if (jobType == JobTypes.cve) {
                dependencyCheck('**/target/dependency-check-report.xml')
            }

            htmlPublisher {
                reportTargets {
                    if (jobType == JobTypes.cve) {
                        htmlPublisherTarget {
                            reportName('CVE-Dependency Check Report Details')
                            reportDir('.')
                            reportFiles('**/target/dependency-check-report.html')
                            keepAll(false)
                            alwaysLinkToLastBuild(false)
                            allowMissing(true)
                        }
                    } else {
                        htmlPublisherTarget {
                            reportName('E2E Report')
                            useWrapperFileDirectly(true)
                            reportTitles('Cypress Test Reports')
                            reportDir('cypress/reports/html')
                            reportFiles('index.html')
                            keepAll(false)
                            alwaysLinkToLastBuild(true)
                            allowMissing(true)
                        }
                    }
                }
            }

            if (onProd) {
                slackNotifier {
                    commitInfoChoice('NONE')
                    customMessage(slackSubject)
                    includeCustomMessage(true)
                    notifyAborted(true)
                    notifyBackToNormal(true)
                    notifyEveryFailure(true)
                    notifyNotBuilt(true)
                    notifyRegression(true)
                    notifySuccess(false)
                    notifyUnstable(true)
                    room(projectSlackChannel)
                    sendAsText(true)
                    includeFailedTests(false)
                    includeTestSummary(false)
                }
            }

            mailer(convertToEmails(projectNotifiedUsers), true, true)
        }
    }
}

GString generateDescription(String projectName, String projectSrcUrl, String projectNexusUrl, String projectGroupArtifact,
                                   String projectBuildTool, String projectLanguage, String projectType, String projectSlackChannel,
                                   String projectNotifiedUsers, Boolean projectUsesBom, String projectDependencies, String projectOwner, String projectNotes,
                                   String cveTableUrl) {
    return """
<div style="border-radius:25px;border:5px solid gray;padding:10px;background:#07AAE0;">
    <font style="color:white;font-size:30px;">${BANNER_MESSAGE}</font><br/>
    <font style="font-family:'Courier New';color:black;font-size:20px;">
       <table>
           <tr><td style="text-align:right;">Project Name:</td><th style="text-align:left;">${projectName}
            - Links:
               <a href="${SPREADSHEET_URL}"><font style="color:white;">Spreadsheet</font></a> /
               <a href="${projectSrcUrl}"><font style="color:white;">Source Code</font></a> /
               <a href="${projectNexusUrl}"><font style="color:white;">Nexus</font></a> /
               <a href="${cveTableUrl}"><font style="color:white;">CVE Summary</font></a>
           </th></tr>
           <tr><td style="text-align:right;">Group and Artifact ID:</td><th style="text-align:left;">${projectGroupArtifact}</th></tr>
           <tr><td style="text-align:right;">Build Tool:</td><th style="text-align:left;">${projectBuildTool}</th></tr>
           <tr><td style="text-align:right;">Language:</td><th style="text-align:left;">${projectLanguage}</th></tr>
           <tr><td style="text-align:right;">Type:</td><th style="text-align:left;">${projectType}</th></tr>
           <tr><td style="text-align:right;">Slack channel:</td><th style="text-align:left;">${projectSlackChannel}</th></tr>
           <tr><td style="text-align:right;">Notified Users:</td><th style="text-align:left;">${projectNotifiedUsers}</th></tr>
           <tr><td style="text-align:right;">Uses BOM?:</td><th style="text-align:left;">${projectUsesBom}</th></tr>
           <tr><td style="text-align:right;">Dependencies:</td><th style="text-align:left;">${projectDependencies}</th></tr>
           <tr><td style="text-align:right;">Owner:</td><th style="text-align:left;">${projectOwner}</th></tr>
           <tr><td style="text-align:right;">Notes:</td><th style="text-align:left;">${projectNotes}</th></tr>
       </table>
    </font>
</div>
"""
}

String convertToEmails(String projectNotifiedUsers) {
    String[] list = projectNotifiedUsers.tokenize("|")
    String result = ''
    Boolean first = true

    for (String email in list) {
        if (first) {
            first = false
        } else {
            result += ','
        }

        if (!email.contains('@')) {
            email += '@snomed.org'
        }

        result += email
    }

    return result
}
