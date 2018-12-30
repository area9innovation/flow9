#!/usr/bin/python

import re
import os
import sys
import shutil

def main():
	testFiles = os.listdir(".")
	
	for testFile in testFiles:
		if testFile.endswith(".flow"):
			try:
				os.remove(testFile + ".jar")
			except OSError:
				pass
			
			try:
				testDir = testFile[:len(testFile) - len('.flow')]
				shutil.rmtree('./' + testDir)
			except OSError:
				pass
			

if __name__ == '__main__':
	main()
