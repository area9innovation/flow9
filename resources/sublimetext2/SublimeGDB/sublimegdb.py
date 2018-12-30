"""
Copyright (c) 2012 Fredrik Ehnbom

This software is provided 'as-is', without any express or implied
warranty. In no event will the authors be held liable for any damages
arising from the use of this software.

Permission is granted to anyone to use this software for any purpose,
including commercial applications, and to alter it and redistribute it
freely, subject to the following restrictions:

   1. The origin of this software must not be misrepresented; you must not
   claim that you wrote the original software. If you use this software
   in a product, an acknowledgment in the product documentation would be
   appreciated but is not required.

   2. Altered source versions must be plainly marked as such, and must not be
   misrepresented as being the original software.

   3. This notice may not be removed or altered from any source
   distribution.
"""
import sublime
import sublime_plugin
import subprocess
import struct
import tempfile
import threading
import time
import traceback
import os
import sys
import re
try:
    import Queue
    from resultparser import parse_result_line

    def sencode(s):
        return s.encode("utf-8")

    def sdecode(s):
        return s

    def bencode(s):
        return s
    def bdecode(s):
        return s
except:
    def sencode(s):
        return s

    def sdecode(s):
        return s

    def bencode(s):
        return s.encode("utf-8")

    def bdecode(s):
        return s.decode("utf-8")

    import queue as Queue
    from SublimeGDB.resultparser import parse_result_line

def get_setting(key, default=None, view=None):
    try:
        if view is None:
            view = sublime.active_window().active_view()
        s = view.settings()
        if s.has("sublimegdb_%s" % key):
            return s.get("sublimegdb_%s" % key)
    except:
        pass
    return sublime.load_settings("SublimeGDB.sublime-settings").get(key, default)


def expand_path(value, window):
    if window is None:
        # Views can apparently be window less, in most instances getting
        # the active_window will be the right choice (for example when
        # previewing a file), but the one instance this is incorrect
        # is during Sublime Text 2 session restore. Apparently it's
        # possible for views to be windowless then too and since it's
        # possible that multiple windows are to be restored, the
        # "wrong" one for this view might be the active one and thus
        # ${project_path} will not be expanded correctly.
        #
        # This will have to remain a known documented issue unless
        # someone can think of something that should be done plugin
        # side to fix this.
        window = sublime.active_window()

    get_existing_files = \
        lambda m: [ path \
            for f in window.folders() \
            for path in [os.path.join(f, m.group('file'))] \
            if os.path.exists(path) \
        ]
    value = re.sub(r'\${project_path:(?P<file>[^}]+)}', lambda m: len(get_existing_files(m)) > 0 and get_existing_files(m)[0] or m.group('file'), value)
    value = re.sub(r'\${env:(?P<variable>.*)}', lambda m: os.getenv(m.group('variable')), value)
    if os.getenv("HOME"):
        value = re.sub(r'\${home}', re.escape(os.getenv('HOME')), value)
    value = re.sub(r'\${folder:(?P<file>.*)}', lambda m: os.path.dirname(m.group('file')), value)
    value = value.replace('\\', os.sep)
    value = value.replace('/', os.sep)

    return value


DEBUG = None
DEBUG_FILE = None
__debug_file_handle = None

gdb_lastresult = ""
gdb_lastline = ""
gdb_cursor = ""
gdb_cursor_position = 0
gdb_last_cursor_view = None
gdb_bkp_layout = {}
gdb_bkp_window = None
gdb_bkp_view = None

gdb_shutting_down = False
gdb_process = None
gdb_stack_frame = None
gdb_stack_index = 0

gdb_nonstop = False

if os.name == 'nt':
    gdb_nonstop = False


gdb_run_status = None
result_regex = re.compile("(?<=\^)[^,\"]*")
collapse_regex = re.compile("{.*}", re.DOTALL)


def normalize(filename):
    if filename is None:
        return None
    return os.path.abspath(os.path.normcase(filename))


def log_debug(line):
    global __debug_file_handle
    global DEBUG
    if DEBUG:
        try:
            if __debug_file_handle is None:
                if DEBUG_FILE == "stdout":
                    __debug_file_handle = sys.stdout
                else:
                    __debug_file_handle = open(DEBUG_FILE, 'a')
            __debug_file_handle.write(line)
        except:
            sublime.error_message("Couldn't write to the debug file. Debug writes will be disabled for this session.\n\nDebug file name used:\n%s\n\nError message\n:%s" % (DEBUG_FILE, traceback.format_exc()))
            DEBUG = False


class GDBView(object):
    def __init__(self, name, s=True, settingsprefix=None):
        self.queue = Queue.Queue()
        self.name = name
        self.closed = True
        self.doScroll = s
        self.view = None
        self.settingsprefix = settingsprefix
        self.timer = None
        self.lines = ""
        self.lock = threading.RLock()

    def is_open(self):
        return not self.closed

    def open_at_start(self):
        if self.settingsprefix is not None:
            return get_setting("%s_open" % self.settingsprefix, False)
        return False

    def open(self):
        if self.view is None or self.view.window() is None:
            if self.settingsprefix is not None:
                sublime.active_window().focus_group(get_setting("%s_group" % self.settingsprefix, 0))
            self.create_view()

    def close(self):
        if self.view is not None:
            if self.settingsprefix is not None:
                sublime.active_window().focus_group(get_setting("%s_group" % self.settingsprefix, 0))
            self.destroy_view()

    def should_update(self):
        return self.is_open() and is_running() and gdb_run_status == "stopped"

    def set_syntax(self, syntax):
        if self.is_open():
            self.get_view().set_syntax_file(syntax)


    def timed_add(self):
        try:
            self.lock.acquire()
            lines = self.lines
            self.lines = ""
            self.timer = None
            self.queue.put((self.do_add_line, lines))
            sublime.set_timeout(self.update, 0)
        finally:
            self.lock.release()


    def add_line(self, line, now=True):
        if self.is_open():
            try:
                self.lock.acquire()
                self.lines += line
                if self.timer:
                    self.timer.cancel()
                if self.lines.count("\n") > 10 or now:
                    self.timed_add()
                else:
                    self.timer = threading.Timer(0.1, self.timed_add)
                    self.timer.start()
            finally:
                self.lock.release()

    def scroll(self, line):
        if self.is_open():
            self.queue.put((self.do_scroll, line))
            sublime.set_timeout(self.update, 0)

    def set_viewport_position(self, pos):
        if self.is_open():
            self.queue.put((self.do_set_viewport_position, pos))
            sublime.set_timeout(self.update, 0)

    def clear(self, now=False):
        if self.is_open():
            if not now:
                self.queue.put((self.do_clear, None))
                sublime.set_timeout(self.update, 0)
            else:
                self.do_clear(None)

    def create_view(self):
        self.view = sublime.active_window().new_file()
        self.view.set_name(self.name)
        self.view.set_scratch(True)
        self.view.set_read_only(True)
        # Setting command_mode to false so that vintage
        # does not eat the "enter" keybinding
        self.view.settings().set('command_mode', False)
        self.closed = False

    def destroy_view(self):
        sublime.active_window().focus_view(self.view)
        sublime.active_window().run_command("close")
        self.view = None
        self.closed = True

    def is_closed(self):
        return self.closed

    def was_closed(self):
        self.closed = True

    def fold_all(self):
        if self.is_open():
            self.queue.put((self.do_fold_all, None))

    def get_view(self):
        return self.view

    def do_add_line(self, line):
        self.view.run_command("gdb_view_add_line", {"line": line, "doScroll": self.doScroll})

    def do_fold_all(self, data):
        self.view.run_command("fold_all")

    def do_clear(self, data):
        self.view.run_command("gdb_view_clear")

    def do_scroll(self, data):
        self.view.run_command("goto_line", {"line": data + 1})

    def do_set_viewport_position(self, data):
        # Shouldn't have to call viewport_extent, but it
        # seems to flush whatever value is stale so that
        # the following set_viewport_position works.
        # Keeping it around as a WAR until it's fixed
        # in Sublime Text 2.
        self.view.viewport_extent()
        self.view.set_viewport_position(data, False)

    def update(self):
        if not self.is_open():
            return
        try:
            while not self.queue.empty():
                cmd, data = self.queue.get()
                try:
                    cmd(data)
                finally:
                    self.queue.task_done()
        except:
            traceback.print_exc()

    def on_session_ended(self):
        if get_setting("%s_clear_on_end" % self.settingsprefix, True):
            self.clear()


class GdbViewClear(sublime_plugin.TextCommand):
    def run(self, edit):
        self.view.set_read_only(False)
        self.view.erase(edit, sublime.Region(0, self.view.size()))
        self.view.set_read_only(True)

class GdbViewAddLine(sublime_plugin.TextCommand):
    def run(self, edit, line, doScroll):
        self.view.set_read_only(False)
        self.view.insert(edit, self.view.size(), line)
        self.view.set_read_only(True)
        if doScroll:
            self.view.show(self.view.size())

class GDBVariable:
    def __init__(self, vp=None, parent=None):
        self.parent = parent
        self.valuepair = vp
        self.children = []
        self.line = 0
        self.is_expanded = False
        if "value" not in vp:
            self.update_value()
        self.dirty = False
        self.deleted = False

    def delete(self):
        run_cmd("-var-delete %s" % self.get_name())
        self.deleted = True

    def update_value(self):
        line = run_cmd("-var-evaluate-expression %s" % self["name"], True)
        if get_result(line) == "done":
            self['value'] = parse_result_line(line)["value"]

    def update(self, d):
        for key in d:
            if key.startswith("new_"):
                if key == "new_num_children":
                    self["numchild"] = d[key]
                else:
                    self[key[4:]] = d[key]
            elif key == "value":
                self[key] = d[key]

    def get_expression(self):
        expression = ""
        parent = self.parent
        while parent is not None:
            ispointer = "typecode" in parent and parent["typecode"] == "PTR"
            expression = "%s%s%s" % (parent["exp"], "->" if ispointer else ".", expression)
            parent = parent.parent
        expression += self["exp"]
        return expression

    def add_children(self, name):
        children = listify(parse_result_line(run_cmd("-var-list-children 1 \"%s\"" % name, True))["children"]["child"])
        for child in children:
            child = GDBVariable(child, parent=self)
            if child.get_name().endswith(".private") or \
                    child.get_name().endswith(".protected") or \
                    child.get_name().endswith(".public"):
                if child.has_children():
                    self.add_children(child.get_name())
            else:
                self.children.append(child)

    def is_editable(self):
        line = run_cmd("-var-show-attributes %s" % (self.get_name()), True)
        return "editable" in re.findall("(?<=attr=\")[a-z]+(?=\")", line)

    def edit_on_done(self, val):
        line = run_cmd("-var-assign %s \"%s\"" % (self.get_name(), val), True)
        if get_result(line) == "done":
            self.valuepair["value"] = parse_result_line(line)["value"]
            gdb_variables_view.update_variables(True)
        else:
            err = line[line.find("msg=") + 4:]
            sublime.status_message("Error: %s" % err)

    def find(self, name):
        if self.deleted:
            return None
        if name == self.get_name():
            return self
        elif name.startswith(self.get_name()):
            for child in self.children:
                ret = child.find(name)
                if ret is not None:
                    return ret
        return None

    def edit(self):
        sublime.active_window().show_input_panel("%s =" % self["exp"], self.valuepair["value"], self.edit_on_done, None, None)

    def get_name(self):
        return self.valuepair["name"]

    def expand(self):
        self.is_expanded = True
        if not (len(self.children) == 0 and int(self.valuepair["numchild"]) > 0):
            return
        self.add_children(self.get_name())

    def has_children(self):
        return int(self.valuepair["numchild"]) > 0

    def collapse(self):
        self.is_expanded = False

    def __str__(self):
        if not "dynamic_type" in self or len(self['dynamic_type']) == 0 or self['dynamic_type'] == self['type']:
            return "%s %s = %s" % (self['type'], self['exp'], self['value'])
        else:
            return "%s %s = (%s) %s" % (self['type'], self['exp'], self['dynamic_type'], self['value'])

    def __iter__(self):
        return self.valuepair.__iter__()

    def __getitem__(self, key):
        return self.valuepair[key]

    def __setitem__(self, key, value):
        self.valuepair[key] = value
        if key == "value":
            self.dirty = True

    def clear_dirty(self):
        self.dirty = False
        for child in self.children:
            child.clear_dirty()

    def is_dirty(self):
        dirt = self.dirty
        if not dirt and not self.is_expanded:
            for child in self.children:
                if child.is_dirty():
                    dirt = True
                    break
        return dirt

    def format(self, indent="", output="", line=0, dirty=[]):
        icon = " "
        if self.has_children():
            if self.is_expanded:
                icon = "-"
            else:
                icon = "+"

        output += "%s%s%s\n" % (indent, icon, self)
        self.line = line
        line = line + 1
        indent += "    "
        if self.is_expanded:
            for child in self.children:
                output, line = child.format(indent, output, line, dirty)
        if self.is_dirty():
            dirty.append(self)
        return (output, line)

def qtod(q):
    val = struct.pack("Q", q)
    return struct.unpack("d", val)[0]

def itof(i):
    val = struct.pack("I", i)
    return struct.unpack("f", val)[0]

class GDBRegister:
    def __init__(self, name, index, val):
        self.name = name
        self.index = index
        self.value = val
        self.line = 0
        self.lines = 0

    def format(self, line=0):
        val = self.value
        if  "{" not in val and re.match(r"[\da-yA-Fx]+", val):
            valh = int(val, 16)&0xffffffffffffffffffffffffffffffff
            six4 = False
            if valh > 0xffffffff:
                six4 = True
            val = struct.pack("Q" if six4 else "I", valh)
            valf = struct.unpack("d" if six4 else "f", val)[0]
            valI = struct.unpack("Q" if six4 else "I", val)[0]
            vali = struct.unpack("q" if six4 else "i", val)[0]

            val = "0x%016x %16.8f %020d %020d" % (valh, valf, valI, vali)
        elif "{" in val:
            match = re.search(r"(.*v4_float\s*=\s*\{)([^}]+)(\}.*v4_int32\s*=\s*\{([^\}]+)\}.*)", val)
            if match:
                floats = re.findall(r"0x[^,\}]+", match.group(4))
                if len(floats) == 4:
                    floats = [str(itof(int(f, 16))) for f in floats]
                    val = match.expand(r"\g<1>%s\g<3>" % ", ".join(floats))
        output = "%8s: %s\n" % (self.name, val)
        self.line = line
        line += output.count("\n")
        self.lines = line - self.line
        return (output, line)

    def set_value(self, val):
        self.value = val

    def set_gdb_value(self, val):
        if "." in val:
            if val.endswith("f"):
                val = struct.unpack("I", struct.pack("f", float(val[:-1])))[0]
            else:
                val = struct.unpack("Q", struct.pack("d", float(val)))[0]

        run_cmd("-data-evaluate-expression $%s=%s" % (self.name, val))

    def edit_on_done(self, val):
        self.set_gdb_value(val)
        gdb_register_view.update_values()

    def edit(self):
        sublime.active_window().show_input_panel("$%s =" % self.name, self.value, self.edit_on_done, None, None)


class GDBRegisterView(GDBView):
    def __init__(self):
        super(GDBRegisterView, self).__init__("GDB Registers", s=False, settingsprefix="registers")
        self.values = None

    def open(self):
        super(GDBRegisterView, self).open()
        self.set_syntax("Packages/SublimeGDB/gdb_registers.tmLanguage")
        self.get_view().settings().set("word_wrap", False)
        if self.is_open() and gdb_run_status == "stopped":
            self.update_values()

    def get_names(self):
        line = run_cmd("-data-list-register-names", True)
        return parse_result_line(line)["register-names"]

    def get_values(self):
        line = run_cmd("-data-list-register-values x", True)
        if get_result(line) != "done":
            return []
        return parse_result_line(line)["register-values"]

    def update_values(self):
        if not self.should_update():
            return
        dirtylist = []
        if self.values is None:
            names = self.get_names()
            vals = self.get_values()
            self.values = []

            for i in range(len(vals)):
                idx = int(vals[i]["number"])
                self.values.append(GDBRegister(names[idx], idx, vals[i]["value"]))
        else:
            dirtylist = regs = parse_result_line(run_cmd("-data-list-changed-registers", True))["changed-registers"]
            regvals = parse_result_line(run_cmd("-data-list-register-values x %s" % " ".join(regs), True))["register-values"]
            for i in range(len(regs)):
                reg = int(regvals[i]["number"])
                if reg < len(self.values):
                    self.values[reg].set_value(regvals[i]["value"])
        pos = self.get_view().viewport_position()
        self.clear()
        line = 0
        for item in self.values:
            output, line = item.format(line)
            self.add_line(output)
        self.set_viewport_position(pos)
        self.update()
        regions = []
        v = self.get_view()
        for dirty in dirtylist:
            i = int(dirty)
            if i >= len(self.values):
                continue
            region = v.full_line(v.text_point(self.values[i].line, 0))
            if self.values[i].lines > 1:
                region = region.cover(v.full_line(v.text_point(self.values[i].line + self.values[i].lines - 1, 0)))

            regions.append(region)
        v.add_regions("sublimegdb.dirtyregisters", regions,
                        get_setting("changed_variable_scope", "entity.name.class"),
                        get_setting("changed_variable_icon", ""),
                        sublime.DRAW_OUTLINED)

    def get_register_at_line(self, line):
        if self.values is None:
            return None
        for i in range(len(self.values)):
            if self.values[i].line == line:
                return self.values[i]
            elif self.values[i].line > line:
                return self.values[i - 1]
        return None


class GDBVariablesView(GDBView):
    def __init__(self):
        super(GDBVariablesView, self).__init__("GDB Variables", False, settingsprefix="variables")
        self.variables = []

    def open(self):
        super(GDBVariablesView, self).open()
        self.set_syntax("Packages/C++/C++.tmLanguage")
        if self.is_open() and gdb_run_status == "stopped":
            self.update_variables(False)

    def update_view(self):
        self.clear()
        output = ""
        line = 0
        dirtylist = []
        for local in self.variables:
            output, line = local.format(line=line, dirty=dirtylist)
            self.add_line(output)
        self.update()
        regions = []
        v = self.get_view()
        for dirty in dirtylist:
            regions.append(v.full_line(v.text_point(dirty.line, 0)))
        v.add_regions("sublimegdb.dirtyvariables", regions,
                        get_setting("changed_variable_scope", "entity.name.class"),
                        get_setting("changed_variable_icon", ""),
                        sublime.DRAW_OUTLINED)

    def extract_varnames(self, res):
        if "name" in res:
            return listify(res["name"])
        elif len(res) > 0 and isinstance(res, list):
            if "name" in res[0]:
                return [x["name"] for x in res]
        return []

    def add_variable(self, exp):
        v = self.create_variable(exp)
        if v:
            self.variables.append(v)

    def create_variable(self, exp):
        line = run_cmd("-var-create - * %s" % exp, True)
        if get_result(line) == "error" and "&" in exp:
            line = run_cmd("-var-create - * %s" % exp.replace("&", ""), True)
        if get_result(line) == "error":
            return None
        var = parse_result_line(line)
        var['exp'] = exp
        return GDBVariable(var)

    def update_variables(self, sameFrame):
        if not self.should_update():
            return
        if sameFrame:
            for var in self.variables:
                var.clear_dirty()
            ret = parse_result_line(run_cmd("-var-update --all-values *", True))["changelist"]
            if "varobj" in ret:
                ret = listify(ret["varobj"])
            dellist = []
            for value in ret:
                name = value["name"]
                for var in self.variables:
                    real = var.find(name)
                    if real is not None:
                        if  "in_scope" in value and value["in_scope"] == "false":
                            real.delete()
                            dellist.append(real)
                            continue
                        real.update(value)
                        if not "value" in value and not "new_value" in value:
                            real.update_value()
                        break
            for item in dellist:
                self.variables.remove(item)
            if len(self.variables) == 0:
                # Is it really the same frame? Seems everything was removed, so might as well pull all data again
                sameFrame = False
            else:
                loc = self.extract_varnames(parse_result_line(run_cmd("-stack-list-locals 0", True))["locals"])
                tracked = []
                for var in loc:
                    create = True
                    for var2 in self.variables:
                        if var2['exp'] == var and var2 not in tracked:
                            tracked.append(var2)
                            create = False
                            break
                    if create:
                        self.add_variable(var)

        if not sameFrame:
            for var in self.variables:
                var.delete()
            args = self.extract_varnames(parse_result_line(run_cmd("-stack-list-arguments 0 %d %d" % (gdb_stack_index, gdb_stack_index), True))["stack-args"]["frame"]["args"])
            self.variables = []
            for arg in args:
                self.add_variable(arg)
            loc = self.extract_varnames(parse_result_line(run_cmd("-stack-list-locals 0", True))["locals"])
            for var in loc:
                self.add_variable(var)
        self.update_view()

    def get_variable_at_line(self, line, var_list=None):
        if var_list is None:
            var_list = self.variables
        if len(var_list) == 0:
            return None

        for i in range(len(var_list)):
            if var_list[i].line == line:
                return var_list[i]
            elif var_list[i].line > line:
                return self.get_variable_at_line(line, var_list[i - 1].children)
        return self.get_variable_at_line(line, var_list[len(var_list) - 1].children)

    def expand_collapse_variable(self, view, expand=True, toggle=False):
        row, col = view.rowcol(view.sel()[0].a)
        if self.is_open() and view.id() == self.get_view().id():
            var = self.get_variable_at_line(row)
            if var and var.has_children():
                if toggle:
                    if var.is_expanded:
                        var.collapse()
                    else:
                        var.expand()
                elif expand:
                    var.expand()
                else:
                    var.collapse()
                pos = view.viewport_position()
                self.update_view()
                self.set_viewport_position(pos)
                self.update()


class GDBCallstackFrame:
    def __init__(self, func, args):
        self.func = func
        self.args = args
        self.lines = 0

    def format(self):
        output = "%s(" % self.func
        for arg in self.args:
            if "name" in arg:
                output += arg["name"]
            if "value" in arg:
                val = arg["value"]
                val = collapse_regex.sub("{...}", val)
                output += " = %s" % val
            output += ","
        output += ");\n"
        self.lines = output.count("\n")
        return output


class GDBCallstackView(GDBView):
    def __init__(self):
        super(GDBCallstackView, self).__init__("GDB Callstack", settingsprefix="callstack")
        self.frames = []

    def open(self):
        super(GDBCallstackView, self).open()
        self.set_syntax("Packages/C++/C++.tmLanguage")
        if self.is_open() and gdb_run_status == "stopped":
            self.update_callstack()

    def update_callstack(self):
        if not self.should_update():
            return
        global gdb_cursor_position
        line = run_cmd("-stack-list-frames", True)
        if get_result(line) == "error":
            gdb_cursor_position = 0
            update_view_markers()
            return
        frames = listify(parse_result_line(line)["stack"]["frame"])
        args = listify(parse_result_line(run_cmd("-stack-list-arguments 1", True))["stack-args"]["frame"])
        pos = self.get_view().viewport_position()
        self.clear()

        self.frames = []
        for i in range(len(frames)):
            arg = {}
            if len(args) > i:
                arg = args[i]["args"]
            f = GDBCallstackFrame(frames[i]["func"], arg)
            self.frames.append(f)
            self.add_line(f.format())
        self.set_viewport_position(pos)
        self.update()

    def update_marker(self, pos_scope, pos_icon):
        if self.is_open():
            view = self.get_view()
            if gdb_stack_index != -1:
                line = 0
                for i in range(gdb_stack_index):
                    line += self.frames[i].lines

                view.add_regions("sublimegdb.stackframe",
                                    [view.line(view.text_point(line, 0))],
                                    pos_scope, pos_icon, sublime.HIDDEN)
            else:
                view.erase_regions("sublimegdb.stackframe")

    def select(self, row):
        line = 0
        for i in range(len(self.frames)):
            fl = self.frames[i].lines
            if row <= line + fl - 1:
                run_cmd("-stack-select-frame %d" % i)
                update_cursor()
                break
            line += fl


class GDBThread:
    def __init__(self, id, state="UNKNOWN", func="???()"):
        self.id = id
        self.state = state
        self.func = func

    def format(self):
        return "%03d - %10s - %s\n" % (self.id, self.state, self.func)


class GDBThreadsView(GDBView):
    def __init__(self):
        super(GDBThreadsView, self).__init__("GDB Threads", s=False, settingsprefix="threads")
        self.threads = []
        self.current_thread = 0

    def open(self):
        super(GDBThreadsView, self).open()
        self.set_syntax("Packages/C++/C++.tmLanguage")
        if self.is_open() and gdb_run_status == "stopped":
            self.update_threads()

    def update_threads(self):
        if not self.should_update():
            return
        res = run_cmd("-thread-info", True)
        ids = parse_result_line(run_cmd("-thread-list-ids", True))
        if get_result(res) == "error":
            if "thread-ids" in ids and "thread-id" in ids["thread-ids"]:
                self.threads = [GDBThread(int(id)) for id in ids["thread-ids"]["thread-id"]]
                if "threads" in ids and "thread" in ids["threads"]:
                    for thread in ids["threads"]["thread"]:
                        if "thread-id" in thread and "state" in thread:
                            tid = int(thread["thread-id"])
                            for t2 in self.threads:
                                if t2.id == tid:
                                    t2.state = thread["state"]
                                    break
                else:
                    l = parse_result_line(run_cmd("-thread-info", True))
            else:
                self.threads = []
        else:
            l = parse_result_line(res)
            self.threads = []
            for thread in l["threads"]:
                func = "???"
                if "frame" in thread and "func" in thread["frame"]:
                    func = thread["frame"]["func"]
                    args = ""
                    if "args" in thread["frame"]:
                        for arg in thread["frame"]["args"]:
                            if len(args) > 0:
                                args += ", "
                            if "name" in arg:
                                args += arg["name"]
                            if "value" in arg:
                                args += " = " + arg["value"]
                    func = "%s(%s);" % (func, args)
                self.threads.append(GDBThread(int(thread["id"]), thread["state"], func))

        if "current-thread-id" in ids:
            self.current_thread = int(ids["current-thread-id"])
        pos = self.get_view().viewport_position()
        self.clear()
        self.threads.sort(key=lambda t: t.id)
        for thread in self.threads:
            self.add_line(thread.format())
        self.set_viewport_position(pos)
        self.update()

    def update_marker(self, pos_scope, pos_icon):
        if self.is_open():
            view = self.get_view()
            line = -1
            for i in range(len(self.threads)):
                if self.threads[i].id == self.current_thread:
                    line = i
                    break

            if line != -1:
                view.add_regions("sublimegdb.currentthread",
                                    [view.line(view.text_point(line, 0))],
                                    pos_scope, pos_icon, sublime.HIDDEN)
            else:
                view.erase_regions("sublimegdb.currentthread")

    def select_thread(self, thread):
        run_cmd("-thread-select %d" % thread)
        self.current_thread = thread

    def select(self, row):
        if row >= len(self.threads):
            return
        self.select_thread(self.threads[row].id)


class GDBDisassemblyView(GDBView):
    def __init__(self):
        super(GDBDisassemblyView, self).__init__("GDB Disassembly", s=False, settingsprefix="disassembly")
        self.start = -1
        self.end = -1

    def open(self):
        super(GDBDisassemblyView, self).open()
        self.set_syntax("Packages/SublimeGDB/gdb_disasm.tmLanguage")
        self.get_view().settings().set("word_wrap", False)
        if self.is_open() and gdb_run_status == "stopped":
            self.update_disassembly()

    def clear(self):
        super(GDBDisassemblyView, self).clear()
        self.start = -1
        self.end = -1

    def add_insns(self, src_asm):
        for asm in src_asm:
            line = "%s: %s" % (asm["address"], asm["inst"])
            if "func-name" in asm:
                self.add_line("%-80s # %s+%s\n" % (line, asm["func-name"], asm["offset"]))
            else:
                self.add_line("%s\n" % line)
            addr = int(asm["address"], 16)
            if self.start == -1 or addr < self.start:
                self.start = addr
            self.end = addr

    def update_disassembly(self):
        if not self.should_update():
            return
        pc = parse_result_line(run_cmd("-data-evaluate-expression $pc", True))["value"]
        if " " in pc:
            pc = pc[:pc.find(" ")]
        pc = int(pc, 16)
        if not (pc >= self.start and pc <= self.end):
            l = run_cmd("-data-disassemble -s \"$pc-32\" -e \"$pc+200\" -- 1", True)
            asms = parse_result_line(l)
            self.clear()
            if get_result(l) != "error":
                asms = asms["asm_insns"]
                if "src_and_asm_line" in asms:
                    l = listify(asms["src_and_asm_line"])
                    for src_asm in l:
                        line = src_asm["line"]
                        file = src_asm["file"]
                        self.add_line("%s:%s\n" % (file, line))
                        self.add_insns(src_asm["line_asm_insn"])
                else:
                    self.add_insns(asms)
            self.update()
        view = self.get_view()
        reg = view.find("^0x[0]*%x:" % pc, 0)
        if reg is None:
            view.erase_regions("sublimegdb.programcounter")
        else:
            pos_scope = get_setting("position_scope", "entity.name.class")
            pos_icon = get_setting("position_icon", "bookmark")
            view.add_regions("sublimegdb.programcounter",
                            [reg],
                            pos_scope, pos_icon, sublime.HIDDEN)


class GDBBreakpoint(object):
    def __init__(self, filename="", line=0, addr=""):
        self.original_filename = normalize(filename)
        self.original_line = line
        self.addr = addr
        self.clear()
        self.add()

    @property
    def line(self):
        if self.number != -1:
            return self.resolved_line
        return self.original_line

    @property
    def filename(self):
        if self.number != -1:
            return normalize(self.resolved_filename)
        return normalize(self.original_filename)

    def clear(self):
        self.resolved_filename = ""
        self.resolved_line = 0
        self.number = -1

    def breakpoint_added(self, res):
        if "bkpt" not in res:
            return
        bp = res["bkpt"]
        if "fullname" in bp:
            self.resolved_filename = bp["fullname"]
        elif "file" in bp:
            self.resolved_filename = bp["file"]
        elif "original-location" in bp and self.addr == 0:
            self.resolved_filename = bp["original-location"].split(":", 1)[0]
            self.resolved_line = int(bp["original-location"].split(":", 1)[1])

        if self.resolved_line == 0 and "line" in bp:
            self.resolved_line = int(bp["line"])

        if not "/" in self.resolved_filename and not "\\" in self.resolved_filename:
            self.resolved_filename = self.original_filename
        self.number = int(bp["number"])

    def insert(self):
        # TODO: does removing the unicode-escape break things? what's the proper way to handle this in python3?
        # cmd = "-break-insert \"\\\"%s\\\":%d\"" % (self.original_filename.encode("unicode-escape"), self.original_line)
        break_cmd = "-break-insert"
        if get_setting("debug_ext") == True:
            break_cmd += " -f"
        if self.addr != "":
            # cmd = "%s *%s" % (break_cmd, self.addr)
            # cmd = "-break-insert %s *%s" % (break_cmd, self.addr)
            cmd = "-break-insert *%s" % self.addr
        else:
            # cmd = "%s \"\\\"%s\\\":%d\"" % (break_cmd, self.original_filename, self.original_line)
            # cmd = "%s \"\\\"%s\\\":%d\"" % (break_cmd, self.original_filename.encode("unicode-escape"), self.original_line.encode("unicode-escape"))
            cmd = "-break-insert \"\\\"%s\\\":%d\"" % (self.original_filename.encode("unicode-escape"), self.original_line)
        out = run_cmd(cmd, True)
        if get_result(out) == "error":
            return
        res = parse_result_line(out)
        if "bkpt" not in res and "matches" in res:
            for match in res["matches"]["b"]:
                cmd = "%s *%s" % (break_cmd, match["addr"])
                out = run_cmd(cmd, True)
                if get_result(out) == "error":
                    return
                res = parse_result_line(out)
                self.breakpoint_added(res)
        else:
            self.breakpoint_added(res)

    def add(self):
        if is_running():
            res = wait_until_stopped()
            self.insert()
            if res:
                resume()

    def remove(self):
        if is_running():
            res = wait_until_stopped()
            run_cmd("-break-delete %s" % self.number)
            if res:
                resume()

    def format(self):
        return "%d - %s:%d\n" % (self.number, self.filename, self.line)


class GDBWatch(GDBBreakpoint):
    def __init__(self, exp):
        self.exp = exp
        super(GDBWatch, self).__init__(None, -1)

    def insert(self):
        out = run_cmd("-break-watch %s" % self.exp, True)
        res = parse_result_line(out)
        if get_result(out) == "error":
            return

        self.number = int(res["wpt"]["number"])

    def format(self):
        return "%d - watch: %s\n" % (self.number, self.exp)


class GDBBreakpointView(GDBView):
    def __init__(self):
        super(GDBBreakpointView, self).__init__("GDB Breakpoints", s=False, settingsprefix="breakpoints")
        self.breakpoints = []

    def open(self):
        super(GDBBreakpointView, self).open()
        # self.set_syntax("Packages/SublimeGDB/gdb_disasm.tmLanguage")
        self.get_view().settings().set("word_wrap", False)
        if self.is_open():
            self.update_view()

    def on_session_ended(self):
        # Intentionally not calling super
        for bkpt in self.breakpoints:
            bkpt.clear()

    def update_marker(self, view):
        bps = []
        fn = view.file_name()
        if fn is None:
            return
        fn = normalize(fn)
        for bkpt in self.breakpoints:
            if bkpt.filename == fn and not (bkpt.line == gdb_cursor_position and fn == gdb_cursor):
                bps.append(view.full_line(view.text_point(bkpt.line - 1, 0)))

        view.add_regions("sublimegdb.breakpoints", bps,
                            get_setting("breakpoint_scope", "keyword.gdb"),
                            get_setting("breakpoint_icon", "circle"),
                            sublime.HIDDEN)

    def find_breakpoint(self, filename, line):
        filename = normalize(filename)
        for bkpt in self.breakpoints:
            if bkpt.filename == filename and bkpt.line == line:
                return bkpt
        return None

    def find_breakpoint_addr(self, addr):
        for bkpt in self.breakpoints:
            if bkpt.addr == addr:
                return bkpt
        return None

    def toggle_watch(self, exp):
        add = True
        for bkpt in self.breakpoints:
            if isinstance(bkpt, GDBWatch) and bkpt.exp == exp:
                add = False
                bkpt.remove()
                self.breakpoints.remove(bkpt)
                break

        if add:
            self.breakpoints.append(GDBWatch(exp))
        self.update_view()

    def toggle_breakpoint_addr(self, addr):
        bkpt = self.find_breakpoint_addr(addr)
        if bkpt:
            bkpt.remove()
            self.breakpoints.remove(bkpt)
        else:
            self.breakpoints.append(GDBBreakpoint(addr=addr))
        self.update_view()

    def toggle_breakpoint(self, filename, line):
        bkpt = self.find_breakpoint(filename, line)
        if bkpt:
            bkpt.remove()
            self.breakpoints.remove(bkpt)
        else:
            self.breakpoints.append(GDBBreakpoint(filename, line))
        self.update_view()

    def sync_breakpoints(self):
        global breakpoints
        for bkpt in self.breakpoints:
            bkpt.add()
        update_view_markers()
        self.update_view()

    def update_view(self):
        if not self.is_open():
            return
        pos = self.get_view().viewport_position()
        self.clear()
        self.breakpoints.sort(key=lambda b: (b.number, b.filename, b.line))
        for bkpt in self.breakpoints:
            self.add_line(bkpt.format())
        self.set_viewport_position(pos)
        self.update()


class GDBSessionView(GDBView):
    def __init__(self):
        super(GDBSessionView, self).__init__("GDB Session", s=False, settingsprefix="session")

    def open(self):
        super(GDBSessionView, self).open()
        self.set_syntax("Packages/SublimeGDB/gdb_session.tmLanguage")


gdb_session_view = GDBSessionView()
gdb_console_view = GDBView("GDB Console", settingsprefix="console")
gdb_variables_view = GDBVariablesView()
gdb_callstack_view = GDBCallstackView()
gdb_register_view = GDBRegisterView()
gdb_disassembly_view = GDBDisassemblyView()
gdb_threads_view = GDBThreadsView()
gdb_breakpoint_view = GDBBreakpointView()
gdb_views = [gdb_session_view, gdb_console_view, gdb_variables_view, gdb_callstack_view, gdb_register_view, gdb_disassembly_view, gdb_threads_view, gdb_breakpoint_view]

def update_view_markers(view=None):
    if view is None:
        view = sublime.active_window().active_view()

    fn = view.file_name()
    if fn is not None:
        fn = normalize(fn)
    pos_scope = get_setting("position_scope", "entity.name.class")
    pos_icon = get_setting("position_icon", "bookmark")

    cursor = []
    if fn == gdb_cursor and gdb_cursor_position != 0:
        cursor.append(view.full_line(view.text_point(gdb_cursor_position - 1, 0)))
    global gdb_last_cursor_view
    if gdb_last_cursor_view is not None:
        gdb_last_cursor_view.erase_regions("sublimegdb.position")
    gdb_last_cursor_view = view
    view.add_regions("sublimegdb.position", cursor, pos_scope, pos_icon, sublime.HIDDEN)

    gdb_callstack_view.update_marker(pos_scope, pos_icon)
    gdb_threads_view.update_marker(pos_scope, pos_icon)
    gdb_breakpoint_view.update_marker(view)

count = 0


def run_cmd(cmd, block=False, mimode=True, timeout=10):
    global count
    if not is_running():
        return "0^error,msg=\"no session running\""

    timeoutcount = timeout/0.001

    ### handle a list of commands by recursively calling run_cmd
    if isinstance(cmd, list):
        for c in cmd:
            run_cmd(c, block, mimode, timeout)
        return count

    if mimode:
        count = count + 1
        cmd = "%d%s\n" % (count, cmd)
    else:
        cmd = "%s\n\n" % cmd
    log_debug(cmd)
    if gdb_session_view is not None:
        gdb_session_view.add_line(cmd, False)
    gdb_process.stdin.write(cmd.encode(sys.getdefaultencoding()))
    if block:
        countstr = "%d^" % count
        i = 0
        while not gdb_lastresult.startswith(countstr) and i < timeoutcount:
            i += 1
            time.sleep(0.001)
        if i >= timeoutcount:
            raise ValueError("Command \"%s\" took longer than %d seconds to perform?" % (cmd, timeout))
        return gdb_lastresult
    return count


def wait_until_stopped():
    if gdb_run_status == "running":
        result = run_cmd("-exec-interrupt --all", True)
        if "^done" in result:
            i = 0
            while not "stopped" in gdb_run_status and i < 100:
                i = i + 1
                time.sleep(0.1)
            if i >= 100:
                print("I'm confused... I think status is %s, but it seems it wasn't..." % gdb_run_status)
                return False
            return True
    return False


def resume():
    global gdb_run_status
    gdb_run_status = "running"
    run_cmd("-exec-continue", True)


def get_result(line):
    return result_regex.search(line).group(0)


def listify(var):
    if not isinstance(var, list):
        return [var]
    return var


def update_cursor():
    global gdb_cursor
    global gdb_cursor_position
    global gdb_stack_index
    global gdb_stack_frame

    res = run_cmd("-stack-info-frame", True)
    if get_result(res) == "error":
        if gdb_run_status != "running":
            print("run_status is %s, but got error: %s" % (gdb_run_status, res))
        return
    currFrame = parse_result_line(res)["frame"]
    gdb_stack_index = int(currFrame["level"])

    if "fullname" in currFrame:
        gdb_cursor = currFrame["fullname"]
        gdb_cursor_position = int(currFrame["line"])
        sublime.active_window().focus_group(get_setting("file_group", 0))
        sublime.active_window().open_file("%s:%d" % (gdb_cursor, gdb_cursor_position), sublime.ENCODED_POSITION)
    else:
        gdb_cursor_position = 0

    sameFrame = gdb_stack_frame is not None and \
                gdb_stack_frame["func"] == currFrame["func"]
    if sameFrame and "shlibname" in currFrame and "shlibname" in gdb_stack_frame:
        sameFrame = currFrame["shlibname"] == gdb_stack_frame["shlibname"]
    if sameFrame and "fullname" in currFrame and "fullname" in gdb_stack_frame:
        sameFrame = currFrame["fullname"] == gdb_stack_frame["fullname"]

    gdb_stack_frame = currFrame
    # Always need to update the callstack since it's possible to
    # end up in the current function from many different call stacks
    gdb_callstack_view.update_callstack()
    gdb_threads_view.update_threads()

    update_view_markers()
    gdb_variables_view.update_variables(sameFrame)
    gdb_register_view.update_values()
    gdb_disassembly_view.update_disassembly()


def session_ended_status_message():
    sublime.status_message("GDB session ended")


def gdboutput(pipe):
    global gdb_process
    global gdb_lastresult
    global gdb_lastline
    global gdb_stack_frame
    global gdb_run_status
    global gdb_stack_index
    command_result_regex = re.compile("^\d+\^")
    run_status_regex = re.compile("(^\d*\*)([^,]+)")

    while True:
        try:
            line = pipe.readline()
            if len(line) == 0:
                break
            line = line.strip().decode(sys.getdefaultencoding())
            log_debug("gdb_%s: %s\n" % ("stdout" if pipe == gdb_process.stdout else "stderr", line))
            gdb_session_view.add_line("%s\n" % line, False)

            run_status = run_status_regex.match(line)
            if run_status is not None:
                gdb_run_status = run_status.group(2)
                reason = re.search("(?<=reason=\")[a-zA-Z0-9\-]+(?=\")", line)
                if reason is not None and reason.group(0).startswith("exited"):
                    run_cmd("-gdb-exit")
                elif not "running" in gdb_run_status and not gdb_shutting_down:
                    thread_id = re.search('thread-id="(\d+)"', line)
                    if thread_id is not None:
                        gdb_threads_view.select_thread(int(thread_id.group(1)))
                    sublime.set_timeout(update_cursor, 0)
            if not line.startswith("(gdb)"):
                gdb_lastline = line
            if command_result_regex.match(line) is not None:
                gdb_lastresult = line

            if line.startswith("~"):
                gdb_console_view.add_line(
                    line[2:-1].replace("\\n", "\n").replace("\\\"", "\"").replace("\\t", "\t"), False)

        except:
            traceback.print_exc()
    if pipe == gdb_process.stdout:
        log_debug("GDB session ended\n")
        gdb_session_view.add_line("GDB session ended\n")
        sublime.set_timeout(session_ended_status_message, 0)
        gdb_stack_frame = None
    global gdb_cursor_position
    gdb_stack_index = -1
    gdb_cursor_position = 0
    gdb_run_status = None
    sublime.set_timeout(update_view_markers, 0)

    for view in gdb_views:
        sublime.set_timeout(view.on_session_ended, 0)
    sublime.set_timeout(cleanup, 0)

def cleanup():
    global __debug_file_handle
    if get_setting("close_views", True):
        for view in gdb_views:
            view.close()
    if get_setting("push_pop_layout", True):
        gdb_bkp_window.set_layout(gdb_bkp_layout)
        gdb_bkp_window.focus_view(gdb_bkp_view)
    if __debug_file_handle is not None:
        if __debug_file_handle != sys.stdout:
            __debug_file_handle.close()
            __debug_file_handle = None


def programio(pty, tty):
    global gdb_process
    exception_count = 0
    class MyFD(object):
        def __init__(self, pty, tty):
            self.pty = pty
            self.tty = tty
            self.off = 0
            self.queue = Queue.Queue()

        def on_done(self, s):
            log_debug("programinput: %s\n" % s)
            log_debug("Wrote: %d bytes\n" % os.write(self.pty, bencode("%s\n" % s)))
            os.fsync(self.pty)
            self.queue.put(None)

        def get_input(self):
            sublime.active_window().show_input_panel("stdin input expected: ", "input", self.on_done, None, lambda: self.queue.put(None))

        def readline(self):
            ret = ""
            while True:
                if not os.isatty(self.pty):
                    s = os.fstat(self.pty)
                    if self.off >= s.st_size and len(ret) == 0:
                        return ret
                else:
                    import select
                    r, w, x = select.select([self.pty], [self.pty], [], 5.0)
                    if len(r) == 0 and len(w) != 0:
                        log_debug("Ready for input\n")
                        sublime.set_timeout(self.get_input, 0)
                        self.queue.get()
                        continue
                    elif len(r) == 0:
                        log_debug("timed out\n")
                        break
                read = os.read(self.pty, 1)
                self.off += len(read)
                ret += bdecode(read)
                if len(read) == 0 or ret.endswith("\n"):
                    break
            return ret

        def close(self):
            os.close(self.pty)
            if self.tty:
                os.close(self.tty)

    pipe = MyFD(pty, tty)

    while exception_count < 100:
        try:
            line = pipe.readline()
            if len(line) > 0:
                log_debug("programoutput: %s" % line)
                gdb_console_view.add_line(line, False)
            else:
                if gdb_process.poll() is not None:
                    break
                time.sleep(0.1)
        except:
            traceback.print_exc()
            exception_count = exception_count + 1
    if pipe is not None:
        pipe.close()


gdb_input_view = None
gdb_command_history = []
gdb_command_history_pos = 0


def set_input(edit, text):
    gdb_input_view.erase(edit, sublime.Region(0, gdb_input_view.size()))
    gdb_input_view.insert(edit, 0, text)


class GdbPrevCmd(sublime_plugin.TextCommand):
    def run(self, edit):
        global gdb_command_history_pos
        if gdb_command_history_pos > 0:
            gdb_command_history_pos -= 1
        if gdb_command_history_pos < len(gdb_command_history):
            set_input(edit, gdb_command_history[gdb_command_history_pos])


class GdbNextCmd(sublime_plugin.TextCommand):
    def run(self, edit):
        global gdb_command_history_pos
        if gdb_command_history_pos < len(gdb_command_history):
            gdb_command_history_pos += 1
        if gdb_command_history_pos < len(gdb_command_history):
            set_input(edit, gdb_command_history[gdb_command_history_pos])
        else:
            set_input(edit, "")


def show_input():
    global gdb_input_view
    global gdb_command_history_pos
    gdb_command_history_pos = len(gdb_command_history)
    gdb_input_view = sublime.active_window().show_input_panel("GDB", "", input_on_done, input_on_change, input_on_cancel)



def input_on_done(s):
    if s.strip() != "quit":
        show_input()
        gdb_command_history.append(s)
    run_cmd(s)


def input_on_cancel():
    pass


def input_on_change(s):
    pass


def is_running():
    return gdb_process is not None and gdb_process.poll() is None


class GdbInput(sublime_plugin.WindowCommand):
    def run(self):
        show_input()


class GdbLaunch(sublime_plugin.WindowCommand):
    def run(self):
        global gdb_process
        global gdb_run_status
        global gdb_bkp_window
        global gdb_bkp_view
        global gdb_bkp_layout
        global gdb_shutting_down
        global DEBUG
        global DEBUG_FILE
        view = self.window.active_view()
        DEBUG = get_setting("debug", False, view)
        DEBUG_FILE = expand_path(get_setting("debug_file", "stdout", view), self.window)
        if DEBUG:
            print("Will write debug info to file: %s" % DEBUG_FILE)
        if gdb_process is None or gdb_process.poll() is not None:
            commandline = get_setting("commandline", view=view)
            if isinstance(commandline, list):
                # backwards compatibility for when the commandline was a list
                commandline = " ".join(commandline)
            commandline = expand_path(commandline, self.window)
            path = expand_path(get_setting("workingdir", "/tmp", view), self.window)
            log_debug("Running: %s\n" % commandline)
            log_debug("In directory: %s\n" % path)
            gdb_process = subprocess.Popen(commandline, shell=True, cwd=path,
                                            stdin=subprocess.PIPE, stdout=subprocess.PIPE)

            log_debug("Process: %s\n" % gdb_process)
            gdb_bkp_window = sublime.active_window()
            #back up current layout before opening the debug one
            #it will be restored when debug is finished
            gdb_bkp_layout = gdb_bkp_window.get_layout()
            gdb_bkp_view = gdb_bkp_window.active_view()
            gdb_bkp_window.set_layout(
                get_setting("layout",
                    {
                        "cols": [0.0, 0.5, 1.0],
                        "rows": [0.0, 0.75, 1.0],
                        "cells": [[0, 0, 2, 1], [0, 1, 1, 2], [1, 1, 2, 2]]
                    }
                )
            )

            for view in gdb_views:
                if view.is_closed() and view.open_at_start():
                    view.open()
                view.clear()

            gdb_shutting_down = False

            t = threading.Thread(target=gdboutput, args=(gdb_process.stdout,))
            t.start()
            try:
                raise Exception("Nope")
                pty, tty = os.openpty()
                name = os.ttyname(tty)
            except:
                pipe, name = tempfile.mkstemp()
                pty, tty = pipe, None
            log_debug("pty: %s, tty: %s, name: %s" % (pty, tty, name))
            t = threading.Thread(target=programio, args=(pty,tty))
            t.start()
            try:
                run_cmd("-gdb-show interpreter", True, timeout=120)
            except:
                sublime.error_message("""\
It seems you're not running gdb with the "mi" interpreter. Please add
"--interpreter=mi" to your gdb command line""")
                gdb_process.stdin.write("quit\n")
                return
            run_cmd("-inferior-tty-set %s" % name, True)

            run_cmd("-gdb-set target-async 1")
            run_cmd("-gdb-set pagination off")
            # if gdb_nonstop:
            #     run_cmd("-gdb-set non-stop on")

            gdb_breakpoint_view.sync_breakpoints()
            gdb_run_status = "running"

            run_cmd(get_setting("exec_cmd", "-exec-run"), True)

            show_input()
        else:
            sublime.status_message("GDB is already running!")

    def is_enabled(self):
        return not is_running()

    def is_visible(self):
        return not is_running()


class GdbContinue(sublime_plugin.WindowCommand):
    def run(self):
        global gdb_cursor_position
        gdb_cursor_position = 0
        update_view_markers()
        resume()

    def is_enabled(self):
        return is_running() and gdb_run_status != "running"

    def is_visible(self):
        return is_running()


class GdbExit(sublime_plugin.WindowCommand):
    def run(self):
        global gdb_shutting_down
        gdb_shutting_down = True
        wait_until_stopped()
        run_cmd("-gdb-exit", True)

    def is_enabled(self):
        return is_running()

    def is_visible(self):
        return is_running()


class GdbPause(sublime_plugin.WindowCommand):
    def run(self):
        run_cmd("-exec-interrupt")

    def is_enabled(self):
        return is_running() and gdb_run_status != "stopped"

    def is_visible(self):
        return is_running() and gdb_run_status != "stopped"


class GdbStepOver(sublime_plugin.WindowCommand):
    def run(self):
        run_cmd("-exec-next")

    def is_enabled(self):
        return is_running() and gdb_run_status != "running"

    def is_visible(self):
        return is_running()


class GdbStepInto(sublime_plugin.WindowCommand):
    def run(self):
        run_cmd("-exec-step")

    def is_enabled(self):
        return is_running() and gdb_run_status != "running"

    def is_visible(self):
        return is_running()


class GdbNextInstruction(sublime_plugin.WindowCommand):
    def run(self):
        run_cmd("-exec-next-instruction")

    def is_enabled(self):
        return is_running() and gdb_run_status != "running"

    def is_visible(self):
        return is_running()


class GdbStepOut(sublime_plugin.WindowCommand):
    def run(self):
        run_cmd("-exec-finish")

    def is_enabled(self):
        return is_running() and gdb_run_status != "running"

    def is_visible(self):
        return is_running()


class GdbAddWatch(sublime_plugin.TextCommand):
    def run(self, edit):
        if gdb_variables_view.is_open() and self.view.id() == gdb_variables_view.get_view().id():
            var = gdb_variables_view.get_variable_at_line(self.view.rowcol(self.view.sel()[0].begin())[0])
            if var is not None:
                gdb_breakpoint_view.toggle_watch(var.get_expression())
            else:
                sublime.status_message("Don't know how to watch that variable")
        else:
            exp = self.view.substr(self.view.word(self.view.sel()[0].begin()))
            gdb_breakpoint_view.toggle_watch(exp)


class GdbToggleBreakpoint(sublime_plugin.TextCommand):
    def run(self, edit):
        fn = self.view.file_name()

        if gdb_breakpoint_view.is_open() and self.view.id() == gdb_breakpoint_view.get_view().id():
            row = self.view.rowcol(self.view.sel()[0].begin())[0]
            if row < len(gdb_breakpoint_view.breakpoints):
                gdb_breakpoint_view.breakpoints[row].remove()
                gdb_breakpoint_view.breakpoints.pop(row)
                gdb_breakpoint_view.update_view()
        elif gdb_variables_view.is_open() and self.view.id() == gdb_variables_view.get_view().id():
            var = gdb_variables_view.get_variable_at_line(self.view.rowcol(self.view.sel()[0].begin())[0])
            if var is not None:
                gdb_breakpoint_view.toggle_watch(var.get_expression())
        elif gdb_disassembly_view.is_open() and self.view.id() == gdb_disassembly_view.get_view().id():
           for sel in self.view.sel():
                line = self.view.substr(self.view.line(sel))
                addr = re.match(r"^[^:]+", line)
                if addr:
                   gdb_breakpoint_view.toggle_breakpoint_addr(addr.group(0))
        elif fn is not None:
            for sel in self.view.sel():
                line, col = self.view.rowcol(sel.a)
                gdb_breakpoint_view.toggle_breakpoint(fn, line + 1)
        update_view_markers(self.view)


class GdbClick(sublime_plugin.TextCommand):
    def run(self, edit):
        if not is_running():
            return

        row, col = self.view.rowcol(self.view.sel()[0].a)
        if gdb_variables_view.is_open() and self.view.id() == gdb_variables_view.get_view().id():
            gdb_variables_view.expand_collapse_variable(self.view, toggle=True)
        elif gdb_callstack_view.is_open() and self.view.id() == gdb_callstack_view.get_view().id():
            gdb_callstack_view.select(row)
        elif gdb_threads_view.is_open() and self.view.id() == gdb_threads_view.get_view().id():
            gdb_threads_view.select(row)
            update_cursor()

    def is_enabled(self):
        return is_running()


class GdbDoubleClick(sublime_plugin.TextCommand):
    def run(self, edit):
        if gdb_variables_view.is_open() and self.view.id() == gdb_variables_view.get_view().id():
            self.view.run_command("gdb_edit_variable")
        else:
            self.view.run_command("gdb_edit_register")

    def is_enabled(self):
        return is_running() and \
                ((gdb_variables_view.is_open() and self.view.id() == gdb_variables_view.get_view().id()) or \
                 (gdb_register_view.is_open() and self.view.id() == gdb_register_view.get_view().id()))


class GdbCollapseVariable(sublime_plugin.TextCommand):
    def run(self, edit):
        gdb_variables_view.expand_collapse_variable(self.view, expand=False)

    def is_enabled(self):
        if not is_running():
            return False
        row, col = self.view.rowcol(self.view.sel()[0].a)
        if gdb_variables_view.is_open() and self.view.id() == gdb_variables_view.get_view().id():
            return True
        return False


class GdbExpandVariable(sublime_plugin.TextCommand):
    def run(self, edit):
        gdb_variables_view.expand_collapse_variable(self.view)

    def is_enabled(self):
        if not is_running():
            return False
        row, col = self.view.rowcol(self.view.sel()[0].a)
        if gdb_variables_view.is_open() and self.view.id() == gdb_variables_view.get_view().id():
            return True
        return False


class GdbEditVariable(sublime_plugin.TextCommand):
    def run(self, edit):
        row, col = self.view.rowcol(self.view.sel()[0].a)
        var = gdb_variables_view.get_variable_at_line(row)
        if var.is_editable():
            var.edit()
        else:
            sublime.status_message("Variable isn't editable")

    def is_enabled(self):
        if not is_running():
            return False
        if gdb_variables_view.is_open() and self.view.id() == gdb_variables_view.get_view().id():
            return True
        return False


class GdbEditRegister(sublime_plugin.TextCommand):
    def run(self, edit):
        row, col = self.view.rowcol(self.view.sel()[0].a)
        reg = gdb_register_view.get_register_at_line(row)
        if not reg is None:
            reg.edit()

    def is_enabled(self):
        if not is_running():
            return False
        if gdb_register_view.is_open() and self.view.id() == gdb_register_view.get_view().id():
            return True
        return False


class GdbEventListener(sublime_plugin.EventListener):
    def on_query_context(self, view, key, operator, operand, match_all):
        if key == "gdb_running":
            return is_running() == operand
        elif key == "gdb_input_view":
            return gdb_input_view is not None and view.id() == gdb_input_view.id()
        elif key.startswith("gdb_"):
            v = gdb_variables_view
            if key.startswith("gdb_register_view"):
                v = gdb_register_view
            elif key.startswith("gdb_disassembly_view"):
                v = gdb_disassembly_view
            if key.endswith("open"):
                return v.is_open() == operand
            else:
                if v.get_view() is None:
                    return False == operand
                return (view.id() == v.get_view().id()) == operand
        return None

    def on_activated(self, view):
        if view.file_name() is not None:
            update_view_markers(view)

    def on_load(self, view):
        if view.file_name() is not None:
            update_view_markers(view)

    def on_close(self, view):
        for v in gdb_views:
            if v.is_open() and view.id() == v.get_view().id():
                v.was_closed()
                break


class GdbOpenSessionView(sublime_plugin.WindowCommand):
    def run(self):
        gdb_session_view.open()

    def is_enabled(self):
        return not gdb_session_view.is_open()

    def is_visible(self):
        return not gdb_session_view.is_open()


class GdbOpenConsoleView(sublime_plugin.WindowCommand):
    def run(self):
        gdb_console_view.open()

    def is_enabled(self):
        return not gdb_console_view.is_open()

    def is_visible(self):
        return not gdb_console_view.is_open()


class GdbOpenVariablesView(sublime_plugin.WindowCommand):
    def run(self):
        gdb_variables_view.open()

    def is_enabled(self):
        return not gdb_variables_view.is_open()

    def is_visible(self):
        return not gdb_variables_view.is_open()


class GdbOpenCallstackView(sublime_plugin.WindowCommand):
    def run(self):
        gdb_callstack_view.open()

    def is_enabled(self):
        return not gdb_callstack_view.is_open()

    def is_visible(self):
        return not gdb_callstack_view.is_open()


class GdbOpenRegisterView(sublime_plugin.WindowCommand):
    def run(self):
        gdb_register_view.open()

    def is_enabled(self):
        return not gdb_register_view.is_open()

    def is_visible(self):
        return not gdb_register_view.is_open()


class GdbOpenDisassemblyView(sublime_plugin.WindowCommand):
    def run(self):
        gdb_disassembly_view.open()

    def is_enabled(self):
        return not gdb_disassembly_view.is_open()

    def is_visible(self):
        return not gdb_disassembly_view.is_open()


class GdbOpenBreakpointView(sublime_plugin.WindowCommand):
    def run(self):
        gdb_breakpoint_view.open()

    def is_enabled(self):
        return not gdb_breakpoint_view.is_open()

    def is_visible(self):
        return not gdb_breakpoint_view.is_open()


class GdbOpenThreadsView(sublime_plugin.WindowCommand):
    def run(self):
        gdb_threads_view.open()

    def is_enabled(self):
        return not gdb_threads_view.is_open()

    def is_visible(self):
        return not gdb_threads_view.is_open()

