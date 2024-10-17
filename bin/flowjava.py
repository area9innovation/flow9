import glob
import os
import shutil
import sys

javafx = "javafx-sdk-17.0.12"
javafxModules = "javafx.controls,javafx.fxml,javafx.base,javafx.graphics"
javafxSubstituteHosts = "java-sub-host=RenderSupport=com.area9innovation.flow.javafx.FxRenderSupport,FlowRuntime=com.area9innovation.flow.javafx.FxFlowRuntime"
javafxJavaFiles = "javafx/com/area9innovation/flow/javafx/*.java"

websocket = "java-websocket-1.5.1/*"

usage = """
Run flow file using java target.
Usage:
	flowjava [OPTIONS] flow-file [-- flow-arguments]
Options:
	-I folder    include path for flowc compiler
	--batch      run without UI
	--debug      generate debugging info by javac
	--verbose    verbose compiling
	--help       print this help and exit
"""

def runCmd(cmd, verbose, allowAnyResult=False):
	if verbose:
		print(f"Running: {cmd}\n")
	code = os.system(cmd)
	if code:
		if not allowAnyResult:
			print("Compilation error " + str(code))
		quit(code)


def getArgs():
	flowArgs = []
	flowFile = ""
	addInclude = False
	isBatch = False
	isDebug = False
	isVerbose = False
	includes = []

	isCompilerArg = True
	for arg in sys.argv[1:]:
		if (isCompilerArg and arg == "--"):
			isCompilerArg = False
		elif isCompilerArg:
			if addInclude:
				includes.append(arg)
				addInclude = False
			elif arg == "--help" or arg == "-h":
				print(usage)
				quit(1)
			elif arg == "--batch":
				isBatch = True
			elif arg == "--debug":
				isDebug = True
			elif arg == "--verbose":
				isVerbose = True
			elif arg == "-I":
				addInclude = True
			elif not flowFile and arg[-5:] == ".flow":
				flowFile = arg
			else:
				print("WARNING: unexpected argument: " + arg)
		else:
			flowArgs.append(arg)
	if flowFile:
		return {
			"flowFile": flowFile,
			"includes": includes,
			"flowArgs": " ".join(flowArgs),
			"isBatch": isBatch,
			"isDebug": isDebug,
			"isVerbose": isVerbose,
		}
	else:
		print("ERROR: Missing flow file argument!")
		print(usage)
		quit(1)


def main():
	global javafxSubstituteHosts, javafxJavaFiles
	args = getArgs()

	osName = sys.platform
	if (osName == "darwin"):
		osName = "macos"
	elif osName[:3] == "win":
		osName = "windows"

	currentPath = os.path.abspath(".")
	binPath = os.path.dirname(os.path.abspath(__file__))
	flowPath = os.path.dirname(binPath)
	libPath = os.path.join(flowPath, "platforms", "java", "lib")
	fxPath = os.path.join(libPath, javafx, osName, "lib")
	commonBuildPath = os.path.join(flowPath, "platforms", "java", "build")
	javagenPath = os.path.join(flowPath, "javagen")
	javagenBuildPath = os.path.join(javagenPath, "build")

	separator = ";" if osName == "windows" else ":"
	libs = separator.join(glob.glob(os.path.join(libPath, "*.jar"))) + separator + os.path.join(libPath, websocket)

	flowFile2 = args["flowFile"][:-5] # no extension ".flow"
	javaClass = flowFile2.replace("/", ".").replace("\\", ".") + "." + os.path.basename(flowFile2)

	if args["isBatch"]:
		mainClass = javaClass
		javafxSubstituteHosts = ""
		javafxJavaFiles = ""
		javafxPathAndModules = ""
	else:
		mainClass = "com.area9innovation.flow.javafx.FxLoader"
		javafxPathAndModules = f"--module-path {fxPath} --add-modules {javafxModules}"

	includes = args["includes"]
	if includes:
		includes = "I=" + ",".join(includes)
	else:
		includes = ""

	shutil.rmtree(javagenPath, ignore_errors=True)
	if os.path.isdir(javagenPath):
		print("WARNING! Cannot clear javagen folder")

	def run(cmd, allowAnyResult=False):
		runCmd(cmd, args["isVerbose"], allowAnyResult)

	# compile common files to the commonBuildPath folder
	os.chdir(os.path.join(flowPath, "platforms", "java"))
	run(f"javac -d build {javafxPathAndModules} -classpath \"{libs}\" -g com/area9innovation/flow/*.java {javafxJavaFiles}")
	os.chdir(currentPath)

	# Generate java files from flow code
	run(f"flowc1 {'verbose=1' if args['isVerbose'] else ''} {includes} {javafxSubstituteHosts} file={args['flowFile']} java={javagenPath}")

	# Compile the generated java code
	run(f"javac -d {javagenBuildPath} -Xlint:unchecked {javafxPathAndModules} -encoding UTF-8 {'-g' if args['isDebug'] else ''} -cp {commonBuildPath} {os.path.join(javagenPath, flowFile2, '*.java')}")

	# Run the program!
	run(f"java {javafxPathAndModules} -cp \"{libs}\"{separator}{commonBuildPath}{separator}{javagenBuildPath} {mainClass} --flowapp={javaClass} {args['flowArgs']}", True)


if __name__ == '__main__':
	main()
