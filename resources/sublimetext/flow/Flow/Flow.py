import sublime
import sublime_plugin
import subprocess
import re
import os
import sys
import codecs
import time
from glob import glob
from threading import Thread

# ------------------------------------------------------------------
# utils
# ------------------------------------------------------------------

# For debugging purposes. Normally should be False
debug = False

def normalizePath(pth):
    if sys.platform.startswith("win"):
        return pth.replace('\\', '/').lower()
    else:
        return pth.replace('\\', '/')

# this tries to locate base flow dir
# better way is to set it manually at User settings of Sublime Text.
# open Preferences -> Settings-User
# add line "flowdir":"c:/flow9",
# where c:/flow is your base flow dir


def flowdir(view):
    res = basedir(view)
    if (res == ''):
        res = flowdir2(view)
    if (res == ''):
        if (view.file_name() is not None):
            res = os.path.dirname(view.file_name())
        else:
            raise Exception("Cannot infer flow dir.\n" +
                            "Add correct flowdir in file Flow.sublime-settings inside Flow plugin folder.")
    if debug: 
        print("flowdir: finally "+res)
    return res


# this returns all project folders
# also tries to find and return ../flow9/ dirs from them


def flowdirs(view):

    res = []
    folders = view.window().folders()
    for f in folders:
        if f.find(' ') >= 0:
            continue
        f1 = normalizePath(f) + '/'
        x1 = f1.find('/flow9/')
        if x1 > 0:
            f2 = f1[:x1+5]
            if os.path.isdir(f2):
                if f2 not in res:
                    res.append(f2)

    for f in folders:
        if f.find(' ') >= 0:
            continue
        f1 = normalizePath(f)
        if os.path.isdir(f1):
            if f1 not in res:
                res.append(f1)
    return res


def flowdir2(view):
    fd = view.settings().get('flowdir')
    if (not fd is None) and (fd != ''):
        if debug:
            print("flowdir: found in globals... "+fd)
        return fd
    fd = sublime.load_settings('Flow.sublime-settings').get('flowdir')
    if (not fd is None) and (fd != ''):
        if debug:
            print("flowdir: settings found in Flow.sublime-settings..."+fd)
        return fd
    fn = view.file_name()
    fp = -1
    if fn is not None:
        fp = fn.find(os.path.sep + "flow" + os.path.sep)

    if fp >= 0:
        return fn[0:fp] + os.path.sep + "flow"
    fd = ''
    return fd


# search flowdir from project folders considering, there must be certain file
def flowdirf(view, filename):
    filename = normalizePath(filename)
    folders = view.window().folders()
    for fld in folders:
        f2 = normalizePath(fld)
        if os.path.exists(f2 + '/' + filename):
            if debug:
                print("flowdirf: finally " + f2)
            return f2
    return flowdir(view)


def filename2projectpath(view, filename):
    filename = normalizePath(filename)

    folders = view.window().folders()
    if len(folders) < 1:
        return os.path.dirname(filename)
    for fld in sorted(folders, key = lambda x: len(x), reverse = False):
        f2 = normalizePath(fld)
        if filename.startswith(f2 + "/"):
            if debug:
                print("filename2projectpath: finally " + f2)
            return f2
    return os.path.dirname(filename)


# Try to guess the root of the current source tree.
#
# The returned path must always be an initial substring of the view's
# path, because the next thing the caller is likely to do with the result
# is use it to convert the view path from absolute to relative by chopping
# off the initial part.
#
# The following code won't work in every conceivable case, because we don't
# know what include paths the user might be planning to pass to the compiler
# with -I.  So we try a series of strategies.

def basedir(view):
    file = view.file_name()
    # we look foor possible folders from bound window, containing the flow dir
    folders = []
    curr_window = view.window()
    if curr_window is not None:
        folders = view.window().folders()

    # if we don't have file bound to view, there's no clues where to look at, so we give up
    if file is None:
        return ''

    # under currently open project? if so return that
    if len(folders) > 0:
        project_root = folders[0]
        if file.find(project_root) is 0:
            return project_root

    # maybe there's a directory somewhere above us called "flow".
    # if so return that.
    dir_name = normalizePath(os.path.dirname(file))+'/'
    x1 = dir_name.find('/flow9/')
    if x1 > 0:
        return dir_name[:x1+6]

    # maybe there's a directory somewhere above us with a *.sublime-project file.
    # if so return that directory.
    walk = dir_name
    walk_prev = ""
    while walk != walk_prev:
        if glob(walk + os.path.sep + "*.sublime-project"):
            return walk
        walk_prev = walk
        walk = os.path.dirname(walk)
    # give up, return none
    return ''

# Try to guess the most shallow path, which includes any flow sources / configs.
# This directory is considered a common storage of all flow projects, and is
# used for global refactoring operations like renaming of functions / types,
# which may affect arbitrary set of sources systemwise.

def rootdir(view):
    afile = view.file_name()
    
    # if we don't have file bound to view, there's no clues where to look at, so we give up
    if afile is None:
        return None

    # this lambda checks if a given dir contains any flow sources or configs
    dir_contains_flow_stuff = lambda adir : glob(adir + os.path.sep + "*.flow") or os.path.isfile(adir + os.path.sep + "flow.config");

    # first of all, get to the most shallow path, which is a prefix of current file path
    # and contains any flow sources / configs
    uppermost_source_dir = normalizePath(os.path.dirname(afile)) + '/'
    walk = uppermost_source_dir
    walk_prev = ""
    while walk != walk_prev:
        if dir_contains_flow_stuff(walk):
            uppermost_source_dir = walk
        walk_prev = walk
        walk = os.path.dirname(walk)
        
    # then, get to the most shallow prefix of 'uppermost_source_dir', which has a sibling 
    # directory containing flow sources / configs
    walk = uppermost_source_dir
    walk_prev = os.path.dirname(walk)
    while walk != walk_prev:
        siblings_with_flow_files = 0
        all_siblings = os.listdir(walk + os.path.sep)
        
        # check, if sibling directories contain flow sources or flow configs
        for sibling_dir in all_siblings:
            if dir_contains_flow_stuff(walk + os.path.sep + sibling_dir):
                siblings_with_flow_files += 1
                
        # A heuristic: siblings with flowfiles must be not less, then 1/3 of all siblings,
        # otherwise the previous dir is what we search for
        if siblings_with_flow_files * 3 < len(all_siblings):
            return walk_prev
        walk_prev = walk
        walk = os.path.dirname(walk)
        
    # if we get here, actually it means that the uppermost source dir is /.
    return uppermost_source_dir

def popenAndCall(onExit, cmd, flowdir, show_out, info = None):
    """
    Runs the given args in a subprocess.Popen, and then calls the function
    onExit when the subprocess completes.
    onExit is a callable object, and popenArgs is a list/tuple of args that 
    would give to subprocess.Popen.
    """
    def runInThread(onExit, cmd, flowdir, info):
        if info == None:
            proc = subprocess.Popen(cmd, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, cwd=flowdir)
        else:
            proc = subprocess.Popen(cmd, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, cwd=flowdir, startupinfo=info)

        if show_out:
            while proc.poll() is None:
                output = proc.stdout.readline()
                if output:
                    print(output.decode("utf-8").replace("\r", "").strip())
            output = proc.stdout.readline()
            if output:
                print(output.decode("utf-8").replace("\r", "").strip())
        proc.wait()
        onExit(proc.returncode)
    
    thread = Thread(target=runInThread, args=(onExit, cmd, flowdir, info))
    thread.start()
    # returns immediately after the thread starts
    return thread

def defaultExitCallback(retcode):
    if retcode == 0: 
        sublime.message_dialog('Operation finished') 
    else:
        sublime.error_message('Operation failed')

def runcmd_in_thread(flow_dir, cmd, onExit = defaultExitCallback, show_out = True):
    try:
        print ("cmd = " + " ".join(cmd))
        if sys.platform.startswith("win"):
            info = subprocess.STARTUPINFO()
            info.dwFlags |= subprocess.STARTF_USESHOWWINDOW
            info.wShowWindow = subprocess.SW_HIDE
            popenAndCall(onExit, cmd, flow_dir, show_out, info)
        else:
            popenAndCall(onExit, cmd, flow_dir, show_out)
    except OSError as ex:
        print ("Could not run " + repr(cmd) + " in " + flow_dir + ": " + repr(ex))
        return "", "", True

def runcmd_base(flow_dir, cmd):
    try:
        if sys.platform.startswith("win"):
            info = subprocess.STARTUPINFO()
            info.dwFlags |= subprocess.STARTF_USESHOWWINDOW
            info.wShowWindow = subprocess.SW_HIDE
            p = subprocess.Popen(cmd, stdout=subprocess.PIPE, stderr=subprocess.PIPE, cwd=flow_dir, startupinfo=info)
        else:
            p = subprocess.Popen(cmd, stdout=subprocess.PIPE, stderr=subprocess.PIPE, cwd=flow_dir)
        output, errors = p.communicate() 
        return output, errors, False
    except OSError as ex:
        print ("Could not run " + repr(cmd) + " in " + flow_dir + ": " + repr(ex))
        return "", "", True


def runcmdWithOutput(self, flow_dir, cmd):
    print ("cmd = " + " ".join(cmd))
    output, errors, fail = runcmd_base(flow_dir, cmd)
    if fail:
        return False
    file_regex = "^(([A-Za-z]:[\\\/]?)?[^:]*?):([0-9]+?)[: ]"
    path_regex = "\(([A-Z:\/]?[^\)]*):"
    decoded_out = output.decode("utf-8").replace("\r", "")
    decoded_err = errors.decode('utf-8').replace('\r', '')
    
    if decoded_out != "":
        print('output:\n' + decoded_out)
    if decoded_err != "":
        print('errors:\n' + decoded_err)

    lines = decoded_out.splitlines()

    p = re.compile(file_regex)
    path = re.compile(path_regex)
    for l in lines:
        match = p.match(l)
        matchPath = path.search(l)
        if not match is None and not matchPath is None:
            defFile = match.group(1)
            defLine = match.group(3)
            targetFile = matchPath.group(1)
            if sys.platform.startswith("win"):
                if not ":" in targetFile:
                    targetFile = flow_dir + os.path.sep + targetFile
            print ("targetFile = " + targetFile)

            if not os.path.exists(targetFile):
                err_msg = "There is no such file as: " + targetFile + "\n" + decoded_out
                sublime.error_message(err_msg)
                return decoded_out, decoded_err + [err_msg]
            else:
                # Open the given file at the given line
                view = self.view.window().open_file(targetFile + ":" + defLine, sublime.ENCODED_POSITION)
    return decoded_out, decoded_err

def runcmd(self, flow_dir, cmd):
    out, err = runcmdWithOutput(self, flow_dir, cmd)
    return err == ""

def shellOrBatch(name):
    if sys.platform.startswith("win"):
        return name + ".bat"
    else:
        return name

# The same as run command, except that we do not wait for the process to end
def startProcess(flow_dir, cmd):
    try:
        if sys.platform.startswith("win"):
            info = subprocess.STARTUPINFO()
            info.dwFlags |= subprocess.STARTF_USESHOWWINDOW
            info.wShowWindow = subprocess.SW_HIDE
            subprocess.Popen(cmd, stdout=subprocess.PIPE, stderr=subprocess.PIPE, cwd=flow_dir, startupinfo=info)
        else:
            subprocess.Popen(cmd, stdout=subprocess.PIPE, stderr=subprocess.PIPE, cwd=flow_dir)
        print ("Started " + repr(cmd) + " in " + flow_dir)
    except OSError as ex:
        print ("Could not run " + repr(cmd) + " in " + flow_dir + ": " + repr(ex))
        return "", ""


def extractRelativePath(fdir, pth):
    fdir2 = normalizePath(fdir).lower()
    pth2 = normalizePath(pth).lower()
    if pth2.find(fdir2)==0: return pth[len(fdir)+1:]
    return pth

# Option if flow.config, responsible for compiler choosing
compilerOption = "flowcompiler="

# Default compiler, which is used when it is not specified
defaultCompiler = "flow"

def findCompiler(dir_name):
	try:
		conf_file = open(os.path.join(dir_name, "flow.config"))
		for line in conf_file.readlines():
			if line.lower().startswith(compilerOption.lower()):
				return line[len(compilerOption):].strip(' \n')
		conf_file.close()
		return defaultCompiler
	except IOError:
		prefix_dir = os.path.dirname(dir_name)
		if prefix_dir != dir_name:
			return findCompiler(prefix_dir)
		else:
			return defaultCompiler

def chooseCompiler(flow_dir):
    flow_compiler = findCompiler(flow_dir)    
    if not flow_compiler in ["flow", "flowc", "flowc1", "flowcomplier", "flowcomplier1"]:
        print("Illegal compiler: " + flow_compiler + ", please correct flow.config" )
        return ""
    elif flow_compiler == "flowc" or flow_compiler == "flowcomplier":
        # We do it to be compliant with flowcpp behaviour.
        # In future this 'elif' statement may be removed
        return flow_compiler + '1'
    else:
        return flow_compiler


# ------------------------------------------------------------------
# plugins
# ------------------------------------------------------------------


class FlowFindDefinition(sublime_plugin.TextCommand):
    def run(self, edit):
        file = self.view.file_name()
        flow_dir = flowdir(self.view)
        relfile = file[len(flow_dir) + 1:]
        compiler = chooseCompiler(flow_dir)

        if compiler != "":
            # Expand to cover the word
            self.view.window().run_command("find_under_expand")

            for s in self.view.sel():
                if not s.empty():
                    id = self.view.substr(s)
                    runcmd(self, flow_dir, [shellOrBatch(compiler)] + self.__prepareCompilerArgs(compiler, relfile, id))

    def __prepareCompilerArgs(self, compiler, file, id):
        if compiler == "flowc" or compiler == "flowc1":
            return ["legacy-format=1", "incremental-priority=1", "find-definition=" + id, file]
        else:
            return ["--find-definition", id, file]

class FlowFindType(sublime_plugin.TextCommand):
    def run(self, edit):
        file = self.view.file_name()
        flow_dir = flowdir(self.view)
        relfile = file[len(flow_dir) + 1:]
        compiler = chooseCompiler(flow_dir)

        if compiler == "flowc" or compiler == "flowc1":
            # Expand to cover the word
            self.view.window().run_command("find_under_expand")

            for s in self.view.sel():
                if not s.empty():
                    row, col = self.view.rowcol(s.begin())    
                    out, err = runcmdWithOutput(self, flow_dir, [shellOrBatch(compiler), "find-type=1", "exp-line=" + str(row + 1), "exp-column=" + str(col + 1), relfile])
                    for line in out.split('\n'):
                        if line.lower().startswith("Type=".lower()):
                            out_type = line[len("Type="):].strip(' \n')
                            out_message = '<pre> ' + out_type.replace('<', '&lt;').replace('>', '&gt;') + ' </pre>'
                            self.view.show_popup(out_message, sublime.HIDE_ON_MOUSE_MOVE_AWAY)
                  
def makeGlobalFlowConfig(rootDir, id_from):
    configFile = rootDir + os.path.sep + 'flow.config'
    if os.path.isfile(configFile):
        return False
    else:
        allIncludes = []
        for dirName, subdirList, fileList in os.walk(rootDir):
            if 'flow.config' in fileList:
                config = open(dirName + os.path.sep + 'flow.config').readlines()
                incstring = [line[len("include="):].strip(' \n') for line in config if line.lower().startswith("include=")]
                if len(incstring) > 0:
                    includes = [os.path.normpath(dirName + os.path.sep + inc) for inc in incstring[0].split(',')]
                    allIncludes.extend(includes)
                allIncludes.append(os.path.normpath(dirName))
        allIncludes = list(set(allIncludes))
        open(configFile, 'w').write('include=' + ','.join(allIncludes))
        return True
                  
class FlowRenameIdentifier(sublime_plugin.TextCommand):
    config_created = False
    def rename(self, x):
        self.config_created = makeGlobalFlowConfig(self.root, self.id_from)
        args = [shellOrBatch('flowc1'), 'rename=' + self.id_from, 'to=' + x, "exp-line=" + str(self.row + 1), "exp-column=" + str(self.col + 1), self.relfile]
        runcmd_in_thread(self.root, args, self.renameExitCallback)

    def run(self, edit):
        afile = self.view.file_name()
        self.root = sublime.load_settings('Flow.sublime-settings').get('rootdir', rootdir(self.view)) 
        if self.root == "":
            self.root = rootdir(self.view);
        if self.root == None:
            print('projects root directory is not set and cannot be found heuristically. Set it in Flow.sublime-settings')
            return
        self.relfile = afile[len(self.root) + 1:]
        self.view.window().run_command("find_under_expand")
        for s in self.view.sel():
            if not s.empty():
                self.id_from = self.view.substr(s)
                self.row, self.col = self.view.rowcol(s.begin())
                self.view.window().show_input_panel('replace ' + self.id_from, self.id_from, self.rename, lambda __: True, lambda __: True)
                    
    def renameExitCallback(self, retcode):
        if self.config_created:
            # Remove temporary config file
            os.remove(self.root + os.path.sep + 'flow.config')
        self.original_config = False    
        if retcode == 0: 
            sublime.message_dialog('Renaming finished') 
        else:
            sublime.error_message('Renaming failed')

class CompileFlowFile(sublime_plugin.TextCommand):
    flow_dir = ""
    flow_file = ""
    def run(self, edit):
        file = self.view.file_name()
        self.view.window().run_command('save')
        self.flow_dir = flowdir(self.view).rstrip('/')
        compiler = chooseCompiler(self.flow_dir)
        self.flow_file = file[len(self.flow_dir) + 1:]

        if compiler != "" and runcmd(self, self.flow_dir, [shellOrBatch(compiler)] + self.__prepareCompilerArgs(compiler, self.flow_file)):
            return True
        else:
            return False
            
    def __prepareCompilerArgs(self, compiler, file):
        if compiler == "flowc" or compiler == "flowc1":
            return [file, "debug=1", "bytecode=run.bytecode"]
        else:
            return ["-c", "run.bytecode", "--debuginfo", "run.debug", "-i", file] 

class RunFlowFile(CompileFlowFile):
    def run_flow(self):
        runcmd(self, self.flow_dir, [shellOrBatch("flowcpp"), "run.bytecode", "run.debug"])

    def run(self, edit):
        if super().run(edit):
            Thread(target=self.run_flow, args=[]).start()

class BuildFlowSwf(sublime_plugin.TextCommand):
    def run(self, edit):
        file = self.view.file_name()
        self.view.window().run_command('save')
        flow_dir = flowdir(self.view)
        relfile = file[len(flow_dir) + 1:]
        startProcess(flow_dir, [shellOrBatch("buildswf"), relfile, os.path.splitext(os.path.basename(relfile))[0] + ".swf"])


class RunFlowSwf(sublime_plugin.TextCommand):
    def run(self, edit):
        file = self.view.file_name()
        self.view.window().run_command('save')
        flow_dir = flowdir(self.view)
        relfile = file[len(flow_dir) + 1:]
        startProcess(flow_dir, [shellOrBatch("runswf"), relfile])


class ProfileInstructionFlowFile(sublime_plugin.TextCommand):
    def run(self, edit):
        file = self.view.file_name()
        self.view.window().run_command('save')
        flow_dir = flowdir(self.view)
        relfile = file[len(flow_dir) + 1:]

        if runcmd(self, flow_dir, [shellOrBatch("flow"), "-c", "run.bytecode", "--debuginfo", "run.debug", "-i", relfile]):
            runcmd(self, flow_dir, [shellOrBatch("flowcpp"), "--profile-bytecode", "2000", "run.bytecode", "run.debug"])


class ViewInstructionProfileFlow(sublime_plugin.TextCommand):
    def run(self, edit):
        flow_dir = flowdir(self.view)
        startProcess(flow_dir, [shellOrBatch("flowprof"), "flowprof.ins", "run.debug"])


class ProfileTimeFlowFile(sublime_plugin.TextCommand):
    def run(self, edit):
        file = self.view.file_name()
        self.view.window().run_command('save')
        flow_dir = flowdir(self.view)
        relfile = file[len(flow_dir) + 1:]

        if runcmd(self, flow_dir, [shellOrBatch("flow"), "-c", "run.bytecode", "--debuginfo", "run.debug", "-i", relfile]):
            runcmd(self, flow_dir, [shellOrBatch("flowcpp"), "--profile-time", "1000", "run.bytecode", "run.debug"])


class ViewTimeProfileFlow(sublime_plugin.TextCommand):
    def run(self, edit):
#        file = self.view.file_name()
        flow_dir = flowdir(self.view)
        startProcess(flow_dir, [shellOrBatch("flowprof"), "flowprof.time", "run.debug"])


class ProfileMemoryFlowFile(sublime_plugin.TextCommand):
    def run(self, edit):
        file = self.view.file_name()
        self.view.window().run_command('save')
        flow_dir = flowdir(self.view)
        relfile = file[len(flow_dir) + 1:]

        if runcmd(self, flow_dir, [shellOrBatch("flow"), "-c", "run.bytecode", "--debuginfo", "run.debug", "-i", relfile]):
            runcmd(self, flow_dir, [shellOrBatch("flowcpp"), "--profile-memory", "1024", "run.bytecode", "run.debug"])


class ProfileGarbageFlowFile(sublime_plugin.TextCommand):
    def run(self, edit):
        file = self.view.file_name()
        self.view.window().run_command('save')
        flow_dir = flowdir(self.view)
        relfile = file[len(flow_dir) + 1:]

        if runcmd(self, flow_dir, [shellOrBatch("flow"), "-c", "run.bytecode", "--debuginfo", "run.debug", "-i", relfile]):
            runcmd(self, flow_dir, [shellOrBatch("flowcpp"), "--profile-garbage", "20", "run.bytecode", "run.debug"])


class ViewMemoryProfileFlow(sublime_plugin.TextCommand):
    def run(self, edit):
        flow_dir = flowdir(self.view)
        startProcess(flow_dir, [shellOrBatch("flowprof"), "flowprof.mem", "run.debug"])


class FlowPreview(sublime_plugin.TextCommand):
    def run(self, edit):
        file = self.view.file_name()
        flow_dir = flowdir(self.view)
        relfile = file[len(flow_dir) + 1:]

        sel = self.view.sel()
        row = 0
        col = 0
        for s in sel:
            (row, col) = self.view.rowcol(s.begin())
            args = [shellOrBatch("flow"), "--flow-preview", relfile + ":" + str(row) + ":" + str(col)]
            runcmd(self, flow_dir, args)


class FlowAutoComplete(sublime_plugin.EventListener):
    def on_query_completions(self, view, prefix, locations):
        if not view.match_selector(locations[0], "source.flow"):
            return

        flow_dir = flowdir(view)
        tmpfile = flow_dir + os.path.sep + "tmp.flow"

        text = view.substr(sublime.Region(0, view.size()))

        fobj = codecs.open(tmpfile, "w", "utf-8")
        fobj.write(text)
        fobj.close()

        cmd = shellOrBatch("flowcomplete")

        output, errors, fail = runcmd_base(flow_dir, [cmd, tmpfile, str(locations[0])])

        completions = []
        p = re.compile("^([^(]*?)\\(([0-9]+?) args\\)")
        p2 = re.compile("^([^(]*?)\\((.*)\\)$")
        p3 = re.compile("^(.*\))( -> .*)$")
        for line in output.decode("utf-8").splitlines():
            tmatch = p3.match(line)
            rtype = ""
            if tmatch is None:
                l = line
            else:
                l = tmatch.group(1)
                rtype = tmatch.group(2)
            match = p.match(l)
            if match is None:
                match2 = p2.match(l)
                if match2 is None:
                    completions.append((l, l))
                else:
                    res = match2.group(1) + "("
                    info = match2.group(1) + "("
                    args = match2.group(2).split(", ")
                    for i in range(0, len(args)):
                        if i > 0:
                            res = res + ", "
                            info = info + ", "
                        res = res + "${" + str(i + 1) + ":" + args[i] + "}"
                        info = info + args[i]
                    completions.append((info + ")" + rtype, res + ")"))
            else:
                s = match.group(1) + "("
                for i in range(0, int(match.group(2))):
                    if i > 0:
                        s = s + ", "
                    s = s + "$" + str(i + 1)
                completions.append((line, s + ")"))

        return completions


class EditRefactorFile(sublime_plugin.TextCommand):

    def run(self, edit):
        flow_dir = flowdir(self.view)
        sublime.active_window().open_file(flow_dir + "/tools/flowsplosion/refactor.flowsplosion")


class RunRefactorAll(sublime_plugin.TextCommand):

    def run(self, edit):
        flow_dir = flowdir(self.view)
        runcmd(self, flow_dir, [shellOrBatch("flowsplosion"), "visual=1"])


class RunRefactorFile(sublime_plugin.TextCommand):

    def run(self, edit):
        file = self.view.file_name()
        self.view.window().run_command('save')
        flow_dir = flowdir(self.view)
        # For a single file, we just use the CPP runner, since compiling Java takes a bit
        runcmd(self, flow_dir, [shellOrBatch("flowcpp"), "tools/flowsplosion/flowsplosion.flow", "--", "file=" + file, "folders="])


class FlowFormTesterGeneratorCommand(sublime_plugin.TextCommand):
    def run(self, edit):
        src = self.view.file_name()
        if not src:
            return
        (root, ext) = os.path.splitext(src)
        if ext != '.flow':
            return
        if self.view.is_dirty():
            self.view.run_command("save")
        dst2 = root + '.formtest'
        app = 'tools/formtester/ft_create.flow'
        fdir = normalizePath(flowdirf(self.view, app))
        fdir2 = filename2projectpath(self.view, src)
        fdirs = ';'.join(flowdirs(self.view))
        print('FORM TESTER GEN: flowdirs = '+fdirs)
        src = normalizePath(src[len(fdir2)+1:])
        dst = normalizePath(dst2[len(fdir2)+1:])
        sel = self.view.sel()[0]
        l, c = self.view.rowcol(sel.begin())
        pos = sel.begin()+l
        cmd = [shellOrBatch('flowcpp'), '-I', fdir, '--cgi', app, '--', 'pos='+str(pos), 'flow='+fdir+'', 'flowsrc='+fdirs, 'src='+src+'', 'dst='+dst+'']
        runcmd(self, fdir, cmd)

        self.view.window().open_file(dst2)


class FlowFormTesterRunCommand(sublime_plugin.TextCommand):
    def run(self, edit):
        src = normalizePath(self.view.file_name())
        if not src:
            return
        (root, ext) = os.path.splitext(src)
        if ext != '.formtest':
            print('FORM TESTER RUN: Please, open or create a <name>.formtest file and select it for this command to run.')
            return
        if self.view.is_dirty():
            self.view.run_command("save")
        app = 'tools/formtester/ft_run.flow'
        fdir = normalizePath(flowdirf(self.view, app))
        fdirs = flowdirs(self.view)
        for d in fdirs:
            if src.find(d) == 0:
                src = src[len(d)+1:]
                break
        fdirs = ';'.join(fdirs)
        print('FORM TESTER RUN: flowdirs = '+';'+fdirs)
        if ext != '.formtest':
            return
        cmd = [shellOrBatch('flowcpp'), '-I', fdir, '--screensize', '600', '300',  app, '--', 'flow='+fdir, 'flowsrc='+fdirs, 'config='+src+'', 'windowpos=20,20,1000,700']
        startProcess(fdir, cmd)


class FlowDumpUsesCommand(sublime_plugin.TextCommand):
    def run(self, edit):
        fdir = flowdir(self.view)
        src = extractRelativePath(fdir, normalizePath(self.view.file_name()))
        cmd = [shellOrBatch('flowcpp'), '-I', fdir, 'tools/dump_uses/dump_uses.flow', '--', 'name='+src]
        runcmd(self, fdir, cmd)


class FlowRenameFile(sublime_plugin.TextCommand):
    def cancelled(self):
        sublime.status_message('File rename cancelled')

    def valid(self, pth, search=re.compile(r'[^a-z0-9/_]').search):
        return not bool(search(pth))

    def getNewFilename(self, src, fdir, srcdir, app):
        self.view.window().show_input_panel('Rename  ' + src + '  to: ', src, lambda dst: self.checkNewFilename(src, dst, fdir, srcdir, app), None, self.cancelled)

    def checkNewFilename(self, src, dst, fdir, srcdir, app):
        if dst == '' or dst == src:
            sublime.status_message('Please, enter valid target filename!')
            return
        self.getOldImportName(src, dst, fdir, srcdir, app)

    def getOldImportName(self, src, dst, fdir, srcdir, app):
        old = normalizePath(src[len(srcdir)+1:-5])
        self.view.window().show_input_panel('Enter old import name: ', old, lambda importOld: self.checkOldImportName(src, dst, importOld, fdir, srcdir, app), None, self.cancelled)

    def checkOldImportName(self, src, dst, importOld, fdir, srcdir, app):
        if importOld == '' or not self.valid(importOld):
            sublime.status_message('Please, enter valid flow import name!')
            return
        self.getNewImportName(src, dst, importOld, fdir, srcdir, app)

    def getNewImportName(self, src, dst, importOld, fdir, srcdir, app):
        new = normalizePath(dst[len(srcdir)+1:-5])
        self.view.window().show_input_panel('Enter new import name: ', new, lambda importNew: self.checkNewImportName(src, dst, importOld, importNew, fdir, srcdir, app), None, self.cancelled)

    def checkNewImportName(self, src, dst, importOld, importNew, fdir, srcdir, app):
        if importNew == '' or not self.valid(importNew):
            sublime.status_message('Please, enter valid flow import name!')
            return
        dstf = srcdir + '/' + importNew + '.flow'
        if os.path.isfile(dstf):
            sublime.status_message('Please, set different new name! Target file exists: ' + dstf)
            return
        self.getWantFolders(src, dst, importOld, importNew, fdir, srcdir, app)

    def getWantFolders(self, src, dst, importOld, importNew, fdir, srcdir, app):
        dstfolder = srcdir
        #os.path.dirname(self.view.file_name())
        sublime.status_message('Folder: ' + dstfolder)
        self.view.window().show_input_panel('Enter folder(s) (use comma) with dependent flow files (to replace "import"): ', dstfolder, lambda dstfolders: self.go(src, dst, importOld, importNew, fdir, srcdir, app, dstfolders), None, self.cancelled)

    def go(self, src, dst, importOld, importNew, fdir, srcdir, app, dstfolders):
        fdirs = ';'.join(sorted(flowdirs(self.view), key=lambda x: len(x)))
        print('FLOW RENAME TOOL START...')
        #sublime.status_message('Rename: ' + importOld + '->' + importNew)
        sublime.status_message('Rename tool is running...')
        cmd = [shellOrBatch('flowcpp'), '--screensize', '600', '200', '-I', fdir, app, '--', 'fileFrom=' + src, 'fileTo=' + dst, 'flowdirs=' + fdirs, 'importFrom=' + importOld, 'importTo=' + importNew, 'folders=' + dstfolders]
        startProcess(fdir, cmd)
        v = self.view.window().find_open_file(src)
        if v:
            v.retarget(dst)

    def run(self, edit):
        src = normalizePath(self.view.file_name())
        if not src:
            sublime.status_message('Use command on opened flow file!')
            return
        if self.view.is_dirty():
            self.view.run_command("save")
        (root, ext) = os.path.splitext(src)
        if ext != '.flow':
            sublime.status_message('Use command on opened flow file!')
            return
        app = 'tools/renamefile/renamefile.flow'
        fdir = normalizePath(flowdirf(self.view, app))
        #srcdir = filename2projectpath(self.view, src)
        folders = self.view.window().folders()
        if len(folders) > 0:
            srcdir = normalizePath(folders[0])
        else:
            srcdir = filename2projectpath(self.view, src)
        if srcdir == '':
            sublime.status_message('Please, use this tool on files under project dir!')
            return
        self.getNewFilename(src, fdir, srcdir, app)


class FlowcompilerBaseCompile(sublime_plugin.TextCommand):
    def __init__(self, view):
        super(FlowcompilerBaseCompile, self).__init__(view)
        if (self.view.file_name() is None):
            # sometimes this plugin is initialized when view is not bound to file_name()
            # e.g. for Flowcompiler1CompileBytecodeCommand
            # it is expected and does not break anything
            # raise Exception("Canot infer flow file yet. It's expected error.")
            self.fdir = ''
            self.flowfile = ''
            self.filename = ''
        else:
            self.fdir = flowdir(self.view)
            self.flowfile = extractRelativePath(self.fdir, normalizePath(self.view.file_name()))
            self.filename, ext = os.path.splitext(self.flowfile)
        self.output = None;


    def append(self, text, file_regex, working_dir, panel_name = 'flowcompiler'):
        # get_output_panel doesn't "get" the panel, it *creates* it, 
        # so we should only call get_output_panel once
        if not hasattr(self, 'output_view'):
            self.output_view = sublime.active_window().get_output_panel(panel_name)
            # This line sets up double click behavior.
            self.output_view.settings().set("result_file_regex", file_regex)
            self.output_view.settings().set("result_base_dir", working_dir)

        v = self.output_view
        edit = v.begin_edit()
        v.insert(edit, v.size(), text + '\n')
        v.end_edit(edit)
        v.show(v.size())

        sublime.active_window().run_command("show_panel", {"panel": "output." + panel_name})


    def doRun(self, flow_dir, cmd):
        print ("cmd = " + " ".join(cmd))
        output, errors, fail = runcmd_base(flow_dir, cmd)
        # This regex allows to parse both types of error messages:
        # c:\flow9\tst.flow : 4:5: SYNTAX ERROR
        # and
        # C:\flow9\tst2.flow(4) : Error: Undefined variable println.
        # and allows double click on error line to open corresponding file.
        file_regex = "^([A-Za-z]?:?[^:]*)(?:\(|(?: : ))([0-9]+)(?:(?:\) : )|:)([0-9]*)(?:: )?(.*)"
        decoded = output.decode("utf-8").replace("\r", "")
    
        p = re.compile(file_regex)

        # Set up build console
        self.append(decoded, file_regex, flow_dir)

        lines = decoded.splitlines()

        # Try to open file with error
        for l in lines:
            match = p.match(l)
            if not match is None:
                defFile = match.group(1)
                defLine = match.group(2)
                defChar = match.group(3)
                defError= match.group(4)

                if sys.platform.startswith("win"):
                    if not ":" in defFile:
                        defFile = flow_dir + os.path.sep + targetFile

                if not os.path.exists(defFile):
                    sublime.error_message("There is no such file as: " + defFile + "\n" + output)
                    return False
                else:
                    # Open the given file at the given line (and char if available)
                    view = self.view.window().open_file(defFile + ":" + defLine + ":" + defChar, sublime.ENCODED_POSITION)
                    return False
        return True
    
    def run(self, edit):
        self.doRun(self.fdir, self.cmd)

# Select compiler
class FlowcompilerCompileCommand(FlowcompilerBaseCompile):
    def __init__(self, view):
        super(FlowcompilerCompileCommand, self).__init__(view)
        self.cmd = [shellOrBatch('flowcompiler')]

class Flowcompiler1CompileCommand(FlowcompilerBaseCompile):
    def __init__(self, view):
        super(Flowcompiler1CompileCommand, self).__init__(view)
        self.cmd = [shellOrBatch('flowcompiler1')]

# Add filename to command line
class FlowcompilerSimpleCompileCommand(FlowcompilerCompileCommand):
    def __init__(self, view):
        super(FlowcompilerSimpleCompileCommand, self).__init__(view)
        self.cmd = self.cmd + ["file=" + self.flowfile]

class Flowcompiler1SimpleCompileCommand(Flowcompiler1CompileCommand):
    def __init__(self, view):
        super(Flowcompiler1SimpleCompileCommand, self).__init__(view)
        self.cmd = self.cmd + ["file=" + self.flowfile]

# Add javascript output
class FlowcompilerCompileJavascriptCommand(FlowcompilerSimpleCompileCommand):
    def __init__(self, view):
        super(FlowcompilerCompileJavascriptCommand, self).__init__(view)
        self.cmd = self.cmd + ["js=" + self.filename + ".js"]

class Flowcompiler1CompileJavascriptCommand(Flowcompiler1SimpleCompileCommand):
    def __init__(self, view):
        super(Flowcompiler1CompileJavascriptCommand, self).__init__(view)
        self.cmd = self.cmd + ["js=" + self.filename + ".js"]

# Add javascript (ES6) output
class FlowcompilerCompileJavascript6Command(FlowcompilerSimpleCompileCommand):
    def __init__(self, view):
        super(FlowcompilerCompileJavascript6Command, self).__init__(view)
        self.cmd = self.cmd + ["es6=" + self.filename + ".js"]

class Flowcompiler1CompileJavascript6Command(Flowcompiler1SimpleCompileCommand):
    def __init__(self, view):
        super(Flowcompiler1CompileJavascript6Command, self).__init__(view)
        self.cmd = self.cmd + ["es6=" + self.filename + ".js"]

# Add javascript (Node) output
class FlowcompilerCompileJavascriptNodeCommand(FlowcompilerCompileJavascript6Command):
    def __init__(self, view):
        super(FlowcompilerCompileJavascriptNodeCommand, self).__init__(view)
        self.cmd = self.cmd + ["nodejs=1"]

class Flowcompiler1CompileJavascriptNodeCommand(Flowcompiler1CompileJavascript6Command):
    def __init__(self, view):
        super(Flowcompiler1CompileJavascriptNodeCommand, self).__init__(view)
        self.cmd = self.cmd + ["nodejs=1"]

# Add bytecode output
class FlowcompilerCompileBytecodeCommand(FlowcompilerSimpleCompileCommand):
    def __init__(self, view):
        super(FlowcompilerCompileBytecodeCommand, self).__init__(view)
        self.cmd = self.cmd + ["bytecode=" + self.filename + ".bytecode"]

class Flowcompiler1CompileBytecodeCommand(Flowcompiler1SimpleCompileCommand):
    def __init__(self, view):
        super(Flowcompiler1CompileBytecodeCommand, self).__init__(view)
        self.cmd = self.cmd + ["bytecode=" + self.filename + ".bytecode"]

