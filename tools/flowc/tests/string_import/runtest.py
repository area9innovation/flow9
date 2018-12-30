import os
import sys
import shutil
import subprocess

# Clear all incremental stuff
def clear_stuff():
	if os.path.exists('objc'):
		shutil.rmtree('objc')
	if os.path.exists('object'):
		shutil.rmtree('object')
	if os.path.exists('flowc.debug'):
		os.remove('flowc.debug')
	if os.path.exists('flowc.bytecode'):
		os.remove('flowc.bytecode')

def run_compiler(useMd5):
	if useMd5:
		return subprocess.check_output("flowc verbose=1 use-md5=1 test1.flow", shell=True)
	else:
		return subprocess.check_output("flowc verbose=1 test1.flow", shell=True)

# Check that incremental files are created and loaded
def test1(useMd5):
	result1 = run_compiler(useMd5)
	if not 'Saving incremental for test1_1' in result1.split('\n'):
		print('FAILED 1\n' + result1)
		return False
	if not 'Saving incremental for test1' in result1.split('\n'):
		print('FAILED 2\n' + result1)
		return False
	
	result2 = run_compiler(useMd5)
	if not 'Loaded incremental for test1_1' in result2.split('\n'):
		print('FAILED 3\n' + result2)
		return False
	if not 'Loaded incremental for test1' in result2.split('\n'):
		print('FAILED 4\n' + result2)
		return False
	print('PASSED: Check that incremental files are created and loaded')
	return True
	
	
# Change one inclded string 
def test2(useMd5):
	# Change a file
	content_1 = open('test_content_1').read()
	open('test_content_1', 'w').write(content_1)
	
	result = run_compiler(useMd5)
	if not "Deleting outdated incremental for test1_1, file objc/test1_1.module" in result.split('\n'):
		print('FAILED 1\n' + result)
		return False
	if not "Deleting outdated incremental for test1, file objc/test1.module" in result.split('\n'):
		print('FAILED 2\n' + result)
		return False
	if not 'Saving incremental for test1_1' in result.split('\n'):
		print result
		print('FAILED 3\n' + result)
		return False
	if not 'Saving incremental for test1' in result.split('\n'):
		print result
		print('FAILED 4\n' + result)
		return False
	print('PASSED: Change one inclded string')
	return True

# Change the other inclded string 
def test3(useMd5):
	# Change a file
	content_2 = open('test_content_2').read()
	open('test_content_2', 'w').write(content_2)
	
	result = run_compiler(useMd5)
	if not "Deleting outdated incremental for test1_1, file objc/test1_1.module" in result.split('\n'):
		print('FAILED 1\n' + result)
		return False
	if not "Deleting outdated incremental for test1, file objc/test1.module" in result.split('\n'):
		print('FAILED 2\n' + result)
		return False
	if not 'Saving incremental for test1_1' in result.split('\n'):
		print result
		print('FAILED 3\n' + result)
		return False
	if not 'Saving incremental for test1' in result.split('\n'):
		print result
		print('FAILED 4\n' + result)
		return False
	print('PASSED: Change the other inclded string')
	return True

# Change both inclded strings
def test4(useMd5):
	# Change a file
	content_1 = open('test_content_1').read()
	content_2 = open('test_content_2').read()
	open('test_content_1', 'w').write(content_1)
	open('test_content_2', 'w').write(content_2)
	
	result = run_compiler(useMd5)
	if not "Deleting outdated incremental for test1_1, file objc/test1_1.module" in result.split('\n'):
		print('FAILED 1\n' + result)
		return False
	if not "Deleting outdated incremental for test1, file objc/test1.module" in result.split('\n'):
		print('FAILED 2\n' + result)
		return False
	if not 'Saving incremental for test1_1' in result.split('\n'):
		print result
		print('FAILED 3\n' + result)
		return False
	if not 'Saving incremental for test1' in result.split('\n'):
		print result
		print('FAILED 4\n' + result)
		return False
	print('PASSED: Change both inclded strings')
	return True

# Incremental file is loaded, no changes
def test5(useMd5):
	result = run_compiler(useMd5)
	if not 'Loaded incremental for test1_1' in result.split('\n'):
		print('FAILED 1\n' + result)
		return False
	if not 'Loaded incremental for test1' in result.split('\n'):
		print('FAILED 2\n' + result)
		return False
	print('PASSED: Incremental file is loaded, no changes')
	return True

def runtests():
	clear_stuff()
	tests = [test1, test2, test3, test4, test5]
	i = 1
	print('Testing with no use-md5 option')
	for test in tests:
		sys.stdout.write('TEST ' + str(i) + ' ')
		sys.stdout.flush()
		if not test(False):
			return
		i += 1
		
	clear_stuff()
	print('Testing with use-md5=1 option')
	for test in tests:
		sys.stdout.write('TEST ' + str(i) + ' ')
		sys.stdout.flush()
		if not test(True):
			return
		i += 1;
		
	clear_stuff()

def main():
	runtests()

if __name__ == "__main__":
	main()
