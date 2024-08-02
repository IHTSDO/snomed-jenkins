import hudson.model.Job

import java.util.regex.Pattern

final String PROJECT_LIST_FILE_NAME = '/tmp/prj_list.txt'
final int MINIMUM_NUMBER_OF_LINES=100
final String MANDATORY_FILE_ENDING = "END OF PROJECT LIST"

// First perform some checks to 100% make sure the list of files is good.
File file = new File(PROJECT_LIST_FILE_NAME)

if (!file.exists()) {
    println "Project list is possibly corrupt, it does not exist, bailing out!"
    exit(3)
}

// Get list of projects recently created/updated by jobMake.
def fileText = file.text
def lineCount = fileText.readLines().size()

if (lineCount < MINIMUM_NUMBER_OF_LINES) {
    println "Project list is possibly corrupt, less that ${MINIMUM_NUMBER_OF_LINES} lines, bailing out!"
    exit(1)
}

if(!fileText.trim().endsWith(MANDATORY_FILE_ENDING)){
    println "Project list is possibly corrupt, does not have correct file ending, bailing out!"
    exit(2)
}

int numberChecked = 0
int numberDeleted = 0

// Loop through all projects on jenkins and remove the old ones.
hudson.model.Hudson.getInstance().getAllItems(Job.class).findAll { job ->
    String projectName = job.getFullName()
    numberChecked++

    // Projects starting with Underscore are not deleted.
    if (!projectName.startsWith("_")) {
        // Remove branch name from project name, if it exists.
        if (projectName.count('/') == 2) {
            int index = projectName.lastIndexOf('/')

            if (index >= 0) {
                projectName = projectName.substring(0, index)
            }
        }

        // Does the project exist in the master spreadsheet, i.e. was created recently by jobMake.groovy.
        def pattern = Pattern.compile("(?m)^" + Pattern.quote(projectName) + "\$")
        def matcher = pattern.matcher(fileText)

        if (!matcher.find()) {
            println "Deleting ${projectName}"
            job.delete()
            numberDeleted++
        }
    }
}

println "Number of projects checked: ${numberChecked}"
println "Number of old dead projects deleted: ${numberDeleted}"
