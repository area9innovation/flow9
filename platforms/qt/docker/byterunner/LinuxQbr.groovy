#!groovy

@Library('jenkinslib') _
def flow = new area9.flow.util()

node('Flow') {
	def buildBranch = flow.getJenkinsVar("FLOW_BRANCH", "master");
	
	try {
		stage('SCM') {
			flow.checkoutFlowOpenSource(true, buildBranch)
			flow.checkoutArea9Innovation("asmjit", "flow9/QtByteRunner/asmjit", true, "next")
		}

		stage('Build') {
			withEnv([
				"FLOW=${WORKSPACE}/flow9"
			]) {
				dir("flow9/QtByteRunner/docker/byterunner") {
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
