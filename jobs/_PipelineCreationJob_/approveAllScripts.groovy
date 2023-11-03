// https://gist.github.com/gwsu2008/c99964c55cce59aadb149d2834d5ceaf
import org.jenkinsci.plugins.scriptsecurity.scripts.ScriptApproval

ScriptApproval scriptApproval = ScriptApproval.get()

scriptApproval.pendingScripts.each {
    scriptApproval.approveScript(it.hash)
}

/* Script to clear script approval
$JENKINS_HOME/init.groovy.d/disable-script-security.groovy:
*/

import javaposse.jobdsl.plugin.GlobalJobDslSecurityConfiguration
import jenkins.model.GlobalConfiguration

// disable Job DSL script approval
GlobalConfiguration.all().get(GlobalJobDslSecurityConfiguration.class).useScriptSecurity=false
GlobalConfiguration.all().get(GlobalJobDslSecurityConfiguration.class).save()

