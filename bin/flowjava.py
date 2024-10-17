import glob
import os
import shutil
import sys

javafx = "javafx-sdk-17.0.12"
javafxModules = "--add-modules javafx.controls,javafx.fxml,javafx.base,javafx.graphics"
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

def runCmd(cmd, verbose):
	if verbose:
		print(f"Running: {cmd}\n")
	code = os.system(cmd)
	if code:
		print("Compilation error " + str(code))
		quit(1)


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

	includes = args["includes"]
	if includes:
		includes = "I=" + ",".join(includes)
	else:
		includes = ""

	shutil.rmtree(javagenPath, ignore_errors=True)
	if os.path.isdir(javagenPath):
		print("WARNING! Cannot clear javagen folder")

	def run(cmd):
		runCmd(cmd, args["isVerbose"])

	# compile common files to the commonBuildPath folder
	os.chdir(os.path.join(flowPath, "platforms", "java"))
	run(f"javac -d build --module-path {fxPath} {javafxModules} -classpath \"{libs}\" -g com/area9innovation/flow/*.java javafx/com/area9innovation/flow/javafx/*.java")
	os.chdir(currentPath)

	# Generate java files from flow code
	run(f"flowc1 {'verbose=1' if args['isVerbose'] else ''} {includes} java-sub-host=RenderSupport=com.area9innovation.flow.javafx.FxRenderSupport,FlowRuntime=com.area9innovation.flow.javafx.FxFlowRuntime file={ args['flowFile'] } java={javagenPath}")

	# Compile the generated java code
	run(f"javac -d {javagenBuildPath} -Xlint:unchecked --module-path {fxPath} {javafxModules} -encoding UTF-8 {'-g' if args['isDebug'] else ''} -cp {commonBuildPath} {os.path.join(javagenPath, flowFile2, '*.java')}")

	# Run the program!
	run(f"java --module-path {fxPath} {javafxModules} -cp \"{libs}\"{separator}{commonBuildPath}{separator}{javagenBuildPath} com.area9innovation.flow.javafx.FxLoader --flowapp={javaClass} {args['flowArgs']}")


if __name__ == '__main__':
	main()
