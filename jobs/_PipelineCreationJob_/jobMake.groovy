@Grab('com.xlson.groovycsv:groovycsv:1.3')
import com.xlson.groovycsv.CsvParser
import jenkins.model.Jenkins
import java.security.MessageDigest

def envVars = Jenkins.instance.getGlobalNodeProperties()[0].getEnvVars()

BASEFOLDER = "/tmp/"
SPREADSHEET_FILE_NAME = "${BASEFOLDER}ProjectsDSL.csv"
SPREADSHEET_URL=envVars["SNOMED_SPREADSHEET_URL"]
SPREADSHEET = "${SPREADSHEET_URL}/gviz/tq?tqx=out:csv"
DOWNLOAD = true

// Spreadsheet column names.
COLUMN_JENKINS_BUILD_ENABLED = "Jenkins Build Enabled"
COLUMN_PROJECT_NAME = "Project Name"
COLUMN_GROUP_ARTIFACT = "GroupId:ArtifactID"
COLUMN_BUILD_TOOL = "Build Tool"
COLUMN_LANGUAGE = "Language"
COLUMN_PROJECT_TYPE = "Project Type"
COLUMN_SLACK_CHANNEL = "Slack Channel"
COLUMN_NOTIFIED_USERS = "Notified Users"
COLUMN_USES_BOM = "Uses BOM?"
COLUMN_SNOMED_DEPENDENCIES = "Snomed Dependencies"
COLUMN_OWNER = "Owner"
COLUMN_NOTES = "Notes"

NIGHTLY_TRIGGER='H H(4-7) * * *'
NUMBER_OF_JOBS_TO_KEEP = 5
NUMBER_OF_DAYS_TO_KEEP = 5
NUMBER_OF_NIGHTLY_JOBS_TO_KEEP = 5
BANNER_MESSAGE = "Automated build pipeline job, if you edit this pipeline your changes will be lost on next system startup."

def spreadsheet = new File(SPREADSHEET_FILE_NAME)
println "Reading ${SPREADSHEET_FILE_NAME}"
downloadSpreadsheet(spreadsheet)

spreadsheet.withReader { reader ->
    int noOfProjects = 0
    int noOfEnabledOfProjects = 0
    def projectsEnabled = [:]
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
            makeMainPipelineJob(projectName, row)
        }
    }

    println "Number of projects created: ${noOfEnabledOfProjects}/${noOfProjects}"
}

private void downloadSpreadsheet(def spreadsheet) {
    if (!DOWNLOAD && spreadsheet.exists()) {
        return
    }

    if (spreadsheet.exists()) {
        println "Removing old file ${SPREADSHEET_FILE_NAME}"
        spreadsheet.delete()
    }

    println "Downloading estate spreadsheet from ${SPREADSHEET}"
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

String generateDescription(String projectName, String projectSrcUrl, String projectNexusUrl, String projectGroupArtifact,
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
               <a href="${projectNexusUrl}"><font style="color:white;">Nexus</font></a>
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

    for (email in list) {
        if (first) {
            first = false
        } else {
            result += ','
        }

        if (! email.contains('@')) {
            email += '@snomed.org'
        }

        result += email
    }

    return result
}

void makeMainPipelineJob(def projectName, def row) {
    String projectGroupArtifact = row."${COLUMN_GROUP_ARTIFACT}"
    String projectBuildTool = row."${COLUMN_BUILD_TOOL}".toLowerCase().capitalize()
    String projectLanguage = row."${COLUMN_LANGUAGE}".toLowerCase().capitalize()
    String projectPipeLineType = "${projectBuildTool}_${projectLanguage}"
    String projectType = row."${COLUMN_PROJECT_TYPE}".toLowerCase()
    String projectSlackChannel = row."${COLUMN_SLACK_CHANNEL}".toLowerCase()
    String projectNotifiedUsers = row."${COLUMN_NOTIFIED_USERS}".toLowerCase()
    Boolean projectUsesBom = row."${COLUMN_USES_BOM}".toBoolean()
    String projectDependencies = row."${COLUMN_SNOMED_DEPENDENCIES}"
    String projectOwner = row."${COLUMN_OWNER}"
    String projectNotes = row."${COLUMN_NOTES}"
    String projectSrcUrl = "https://github.com/IHTSDO/${projectName}"
    String projectGitUri = "git@github.com:IHTSDO/${projectName}.git"
    String projectNexusUrl = "https://nexus3.ihtsdotools.org/#browse/browse:debian-snapshots:packages%2Fs%2F${projectGroupArtifact}"
    String cveTableUrl = "/userContent/cveTable.html"
    // This needs to be constant so cannot be a UUID!
    String nameMd5Token = MessageDigest.getInstance("SHA256").digest(projectName.bytes).encodeHex().toString()

    println "Creating build pipeline : ${projectName} [ ${projectPipeLineType} ]"

    folder('jobs') {
        displayName('Normal builds of ALL branches')
        description("""
<div style="border-radius:25px;border:5px solid gray;padding:10px;background:#07AAE0;">
    <font style="color:white;font-size:30px;">Normal Build Jobs - Each job contains all active branches</font><br/>
    <font style="font-family:'Courier New';color:black;font-size:20px;">
       <a href="${SPREADSHEET_URL}"><font style="color:white;">Spreadsheet</font></a>
    </font>
</div>
""")
    }

    def projectNameWithFolder = 'jobs/' + projectName

    folder('nightly') {
        displayName('Nightly Builds of DEVELOP')
        description("""
<div style="border-radius:25px;border:5px solid gray;padding:10px;background:#07AAE0;">
    <font style="color:white;font-size:30px;">Nightly Builds - Develop is built every night to check for issues</font><br/>
    <font style="font-family:'Courier New';color:black;font-size:20px;">
       <a href="${SPREADSHEET_URL}"><font style="color:white;">Spreadsheet</font></a>
    </font>
</div>
""")
    }

    def projectNameWithFolderNightly = 'nightly/' + projectName

    // https://jenkinsci.github.io/job-dsl-plugin/#path/multibranchPipelineJob
    multibranchPipelineJob(projectNameWithFolder) {
        displayName("${projectName}")

        description(generateDescription(projectName, projectSrcUrl, projectNexusUrl, projectGroupArtifact, projectBuildTool, projectLanguage,
            projectType, projectSlackChannel, projectNotifiedUsers, projectUsesBom, projectDependencies, projectOwner, projectNotes, cveTableUrl))

        branchSources {
            git {
                id(projectName)
                remote(projectGitUri)
                includes("")
                excludes("")
            }
        }

         orphanedItemStrategy {
             discardOldItems {
                // What to do with old branches?  Commenting this out means "delete them"
                // daysToKeep(NUMBER_OF_DAYS_TO_KEEP)
             }
         }

        factory {
            pipelineBranchDefaultsProjectFactory {
                // TODO: JCO: test to see if same pipeline can be used for gradle and maven.
                if (projectBuildTool == 'Gradle') {
                    scriptId('SnomedPipeline_' + "Maven_${projectLanguage}")
                } else {
                    scriptId('SnomedPipeline_' + projectPipeLineType)
                }
                useSandbox(true)
            }
        }

        // There is no DSL API hook for the https://plugins.jenkins.io/multibranch-scan-webhook-trigger/
        // so we need to use the XML configure hook to configure.
        // https://jenkinsci.github.io/job-dsl-plugin/#path/multibranchPipelineJob-configure
        // From this tutorial: https://medium.com/@maksymgrebenets/jenkins-job-dsl-configure-block-4a51aa891f7
        configure { node ->
            node / 'triggers' << 'com.igalg.jenkins.plugins.mswt.trigger.ComputedFolderWebHookTrigger' {
                spec ''
                token nameMd5Token
            }
        }
    }

    if (!projectLanguage.toLowerCase().startsWith("jdk")) {
        println "    Skipping nightly for : ${projectName} [ ${projectPipeLineType} ]"
        return
    }

    freeStyleJob(projectNameWithFolderNightly) {
        displayName("${projectName}_Nightly")

        description(generateDescription(projectName, projectSrcUrl, projectNexusUrl, projectGroupArtifact, projectBuildTool, projectLanguage,
                projectType, projectSlackChannel, projectNotifiedUsers, projectUsesBom, projectDependencies, projectOwner, projectNotes, cveTableUrl))

        jdk('jdk17')
        scm { github("IHTSDO/${projectName}", 'develop') }
        triggers { cron(NIGHTLY_TRIGGER) }
        logRotator(-1, NUMBER_OF_NIGHTLY_JOBS_TO_KEEP)
        wrappers { ansiColorBuildWrapper { colorMapName('xterm') } }

        steps {
            shell {
                // Maven returns 1 on build failure, interpret this as unstable, which means the report is ALWAYS generated/published.
                command('mvn clean dependency-check:check -DskipTests || exit 1')
                unstableReturn(1)
            }
        }

        publishers {
            dependencyCheck('**/target/dependency-check-report.xml')

            htmlPublisher {
                reportTargets {
                    htmlPublisherTarget {
                        reportName('CVE-Dependency Check Report Details')
                        reportDir('.')
                        reportFiles('**/target/dependency-check-report.html')
                        keepAll(false)
                        alwaysLinkToLastBuild(false)
                        allowMissing(true)
                    }
                }
            }

            slackNotifier {
                commitInfoChoice('NONE')
                customMessage("Security CVE failure")
                includeCustomMessage(true)
                notifyAborted(true)
                notifyBackToNormal(true)
                notifyEveryFailure(true)
                notifyNotBuilt(true)
                notifyRegression(true)
                notifySuccess(true)
                notifyUnstable(true)
                room(projectSlackChannel)
                sendAsText(true)
                includeFailedTests(false)
                includeTestSummary(false)
            }

            mailer(convertToEmails(projectNotifiedUsers), true, true)
        }
    }
}
