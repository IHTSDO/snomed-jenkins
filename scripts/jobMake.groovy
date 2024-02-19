@Grab('com.xlson.groovycsv:groovycsv:1.3')
import com.xlson.groovycsv.CsvParser
import jenkins.model.Jenkins
import java.security.MessageDigest

def envVars = Jenkins.instance.getGlobalNodeProperties()[0].getEnvVars()

BASEFOLDER = "/tmp/"
SPREADSHEET_FILE_NAME = "${BASEFOLDER}ProjectsDSL.csv"
SPREADSHEET_URL = envVars["SNOMED_SPREADSHEET_URL"]
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
COLUMN_SLACK_CHANNEL = "Slack Channel"
COLUMN_NOTIFIED_USERS = "Notified Users"
COLUMN_USES_BOM = "Uses BOM?"
COLUMN_SNOMED_DEPENDENCIES = "Snomed Dependencies"
COLUMN_OWNER = "Owner"
COLUMN_NOTES = "Notes"

NIGHTLY_TRIGGER_SECURITY = "H H(4-6) * * *"
NIGHTLY_TRIGGER_E2E = "H H(7-8) * * *"
//NUMBER_OF_JOBS_TO_KEEP = 5
//NUMBER_OF_DAYS_TO_KEEP = 5
//NUMBER_OF_NIGHTLY_JOBS_TO_KEEP = 5
BANNER_MESSAGE = "Automated build pipeline job, if you edit this pipeline your changes will be lost on next system startup."

File spreadsheet = new File(SPREADSHEET_FILE_NAME)
println "Reading ${SPREADSHEET_FILE_NAME}"
downloadSpreadsheet(spreadsheet)
makeFolders()

HOOK_FILE = new File('hook_list.txt')
HOOK_FILE.write("")

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
            makeMainPipelineJob(projectName, row)
        }
    }

    println "Number of projects created: ${noOfEnabledOfProjects}/${noOfProjects}"
}

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
    folder('jobs') {
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

    folder('nightly_security') {
        displayName('Nightly Builds of Develop Security')
        description("""
<div style="border-radius:25px;border:5px solid gray;padding:10px;background:#07AAE0;">
    <font style="color:white;font-size:30px;">Nightly Builds - Develop is built every night to check for security issues</font><br/>
    <font style="font-family:'Courier New';color:black;font-size:20px;">
       <a href="${SPREADSHEET_URL}"><font style="color:white;">Spreadsheet</font></a>
    </font>
</div>
""")
    }

    folder('nightly_e2e') {
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
}

void makeMainPipelineJob(String projectName, def row) {
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
    String projectNexusUrl = new String("https://nexus3.ihtsdotools.org/#browse/browse:debian-snapshots:packages%2Fs%2F${projectGroupArtifact}")
    String cveTableUrl = "/userContent/cveTable.html"
    // This needs to be constant so cannot be a UUID!
    String nameMd5Token = MessageDigest.getInstance("SHA256").digest(projectName.bytes).encodeHex().toString()
    String description = new String(generateDescription(projectName, projectSrcUrl, projectNexusUrl, projectGroupArtifact, projectBuildTool, projectLanguage, projectType, projectSlackChannel, projectNotifiedUsers, projectUsesBom, projectDependencies, projectOwner, projectNotes, cveTableUrl))

    println "Creating build pipeline : ${projectName} [ ${projectPipeLineType} ]"

    // Write information needed to make hooks in github.
    HOOK_FILE.append("${nameMd5Token} ${projectName}\n")

    // Full pipelines for majority of branches.
    generatePipeline("jobs", "", "", "", nameMd5Token, projectGitUri, projectName,  description, projectBuildTool, projectLanguage)

    // Setup Nightly Security jobs.
    if (!projectLanguage.toLowerCase().startsWith("jdk")) {
        println "    Skipping security nightly for : ${projectName} [ ${projectPipeLineType} ]"
    } else {
        generatePipeline("nightly_security", "_CVE", "develop", NIGHTLY_TRIGGER_SECURITY, "", projectGitUri, projectName,  description, projectBuildTool, projectLanguage)
    }

    // Setup E2E jobs.
    if (!projectLanguage.toLowerCase().startsWith("typescript")) {
        println "    Skipping E2E nightly for : ${projectName} [ ${projectPipeLineType} ]"
    } else {
        generatePipeline("nightly_e2e", "_E2E", "develop", NIGHTLY_TRIGGER_E2E, "", projectGitUri, projectName, description,  projectBuildTool, projectLanguage)
    }
}

String generatePipeline(String folder, String suffix, String includeBranches, String cronExpression, String md5Token, String projectGitUri, String projectName, String desc, String projectBuildTool, String projectLanguage) {
    String projectPipeLineType = new String("${projectBuildTool}_${projectLanguage}")

    // https://jenkinsci.github.io/job-dsl-plugin/#path/multibranchPipelineJob
    multibranchPipelineJob("${folder}/${projectName}") {
        displayName("${projectName}${suffix}")
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

        if (cronExpression) {
            println "    Adding cron : ${cronExpression}"
            triggers { cron(cronExpression) }
        }

        factory {
            pipelineBranchDefaultsProjectFactory {
                // TODO: JCO: test to see if same pipeline can be used for gradle and maven.
                if (projectBuildTool == 'Gradle') {
                    scriptId("SnomedPipeline_Maven_${projectLanguage}${suffix}")
                } else {
                    scriptId("SnomedPipeline_${projectPipeLineType}${suffix}")
                }
                useSandbox(true)
            }
        }

        if (md5Token) {
            println "    Updating XML for MD5"
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
