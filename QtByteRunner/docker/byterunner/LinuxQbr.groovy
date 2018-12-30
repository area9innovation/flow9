#!groovy

@Library('jenkinslib') _
def flow = new area9.flow.util()

node('Flow') {
	def buildBranch = flow.getJenkinsVar("FLOW_BRANCH", "master");
	
	try {
		stage('SCM') {
			flow.checkoutFlowOpenSource(true, buildBranch)
			flow.checkoutArea9Innovation("asmjit", "flow/QtByteRunner/asmjit", true, "next")
		}

		stage('Build') {
			withEnv([
				"FLOW=${WORKSPACE}/flow"
			]) {
				dir("flow/QtByteRunner/docker/byterunner") {
					docker.withRegistry('', 'area9dockerhub') {
						sh("./build_image.sh")
						sh("./run.sh")
						archiveArtifacts("artifacts/*")
					}
				}
			}
		}
	} catch(any) {
// 		flow.sendFailedEmail("pavel@area9.dk")
		throw any
	}
}
