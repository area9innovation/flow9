#!/usr/bin/python

import re
import os
import sys

def main():
	
	testFiles = os.listdir(".")
	if len(sys.argv) > 1:
		testFiles = [sys.argv[1]]

	currDir = os.getcwd()
	os.chdir("../../../..")
	rootDir = os.getcwd()
	outDir = currDir[len(rootDir):]
	if outDir.startswith('/'):
		outDir = outDir[1:]
	
	for testFile in testFiles:
		if testFile.endswith(".flow"):
			testPath = outDir + "/" + testFile
			testDir = outDir + "/" + testFile[:len(testFile) - len('.flow')]
			cmd = 'bin/build-with-flowc11 ' + testPath + ' ' + testDir + ' --no-runtime'
			
			if os.system(cmd) != 0:
				print('Error during test compilation')
				print('TESTS FAILED')
				os.abort()
			
			testExec = outDir + '/' + testFile + '.jar'
			cmd = 'java -jar ' + testExec
			if os.system(cmd) != 0:
				print('Error during test execution')
				print('TESTS FAILED')
				os.abort()
			
	print('TESTS PASSED')
			

if __name__ == '__main__':
	main()
