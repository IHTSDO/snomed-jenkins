import jenkins.model.*
import java.util.regex.Pattern

jenkins = Jenkins.instance

excludeRegexp = "^[^_].*"
println "excludeRegexp: ${excludeRegexp}"
pattern = Pattern.compile(excludeRegexp)

jobs = jenkins.items.findAll {
    job -> (pattern.matcher(job.name).matches())
}

int count = 0

jobs.each { job ->
    println "Deleting ${job.name}"
    job.delete()
    count++
}

println "\n"
println "Deleted ${count} jobs!\n"
