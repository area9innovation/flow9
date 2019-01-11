import re
import logging
import shlex
import os.path as op
from io import StringIO
import webbrowser
from functools import reduce
from itertools import chain
from importlib import import_module
from collections import namedtuple

import sublime

import flower
from ..pathutils import getBytecodeDebug, newExt
from ..env import expandEnv, expandStr

log = logging.getLogger(flower.NAME)
sublime_exec = import_module('Default.exec')

FILE_PATTERN = r"^(\S+?):(\d+):(\d+)?:? (.*)$"
FILE_REGEX = re.compile(FILE_PATTERN, re.MULTILINE)


# ---------
#  Utility
# ---------

Callback = namedtuple('Callback', 'name, args')

class Default(dict):
    """Dict with default empty string for missing key"""
    def __missing__(self, key):
        log.warning("Missing key `%s` in %s", key, tuple(self.keys()))
        return ""

# -----------
#  Callbacks
# -----------

def prependash(arr):
    """Prepend dashes to non-empty list"""
    return arr and ('--',)+arr


def noneCallback(*args, **kwargs):
    pass


def swapGDBsettings(workdir, name, args):
    cmd = chain(
        ("flowcpp", "--flowc", "--debug-mi"), # flowcompiler hangs
        getBytecodeDebug(workdir, name),
        prependash(args)
    )

    debugline = ' '.join(cmd).strip()
    log.debug("SublimeGDB: %s", debugline)

    SUBLIMEGDB = "SublimeGDB.sublime-settings"
    settings = sublime.load_settings(SUBLIMEGDB)

    dirty = False
    if settings.get('commandline') != debugline:
        settings.set('commandline', debugline)
        dirty = True

    if settings.get('workingdir') != workdir:
        settings.set('workingdir', workdir)
        dirty = True

    if dirty:
        sublime.save_settings(SUBLIMEGDB)


def gdbCallback(workdir, name, args):
    swapGDBsettings(workdir, name, args)
    sublime.active_window().run_command('gdb_launch')


def cppCallback(workdir, name, args):
    bytecode, *_ = getBytecodeDebug('', name)
    cmd = chain(
        ('flowcpp', bytecode),
        prependash(args)
    )
    Executor.run(cmd=cmd, workdir=workdir)


def webCallback(url, name, args):
    weburl = expandStr(url or flower.SETTINGS.get('url'))
    argstr = '&'+'&'.join(args) if args else ''
    furl = weburl.format_map(Default(name=name, args=argstr))
    fullurl = expandEnv(furl)[0]
    log.info('Opening url: %s', fullurl)
    webbrowser.open_new_tab(fullurl)


def tokenCallback(*args, out=None):
    if not args or out is None:
        return

    token_regex, token, phantom, *_ = args

    res = msg = None
    for m in token_regex.finditer(out):
        *res, msg = m.group('path'), m.group('line'), m.group('msg')
        if res:
            break

    if res is None:
        log.info("Can't find token: %s", token)
    else:
        link = '{0}:{1}'.format(*res)
        log.debug('Found definition @ %s', link)
        phantom(msg.replace('\n', ' '), link)


class Executor:
    # save previous run to cleanup phantoms
    executor = None

    @staticmethod
    def split_cmd(cmd):
        """Split glued command for shell to digest"""
        posix = not flower.is_windows()
        reducer = lambda a, b: a.extend(shlex.split(b, posix=posix)) or a
        res = tuple(reduce(reducer, cmd, []))
        return res

    @staticmethod
    def bat_cmd(cmd):
        """Update executable with correct extension"""
        if not (cmd and flower.is_windows()):
            return cmd

        bat = newExt(cmd[0], 'bat')
        binpath = op.join(flower.PATH['bin'], bat)
        if op.exists(binpath):
            return (bat,) + cmd[1:]

        log.error("Can't find `%s`", binpath)
        return cmd

    @classmethod
    def format_cmd(cls, cmd):
        return cls.bat_cmd(cls.split_cmd(cmd))

    @classmethod
    def clean(cls):
        if cls.executor:
            cls.executor.run(hide_phantoms_only=True)

    @classmethod
    def run(cls, cmd, workdir, after=None, quiet=False):
        """Starts Preset+Runner process"""

        after = after or Callback(None, ())
        callback = {
            "cpp":  lambda out: cppCallback(*after.args),
            "gdb":  lambda out: gdbCallback(*after.args),
            "web":  lambda out: webCallback(*after.args),
            "find": lambda out: tokenCallback(*after.args, out=out),
            # "test": lambda out: outputCallback(args, out=out),
        }.get(after.name, noneCallback)

        command = cls.format_cmd(cmd)
        log.debug('Running command (%s):\n\ncd %s; %s\n', after.name, workdir, ' '.join(command))

        cls.clean()
        cls.executor = FlowExecCommand(sublime.active_window())
        cls.executor.run(
            command,
            shell_cmd=None,
            file_regex=FILE_PATTERN,
            working_dir=workdir,
            env={},
            quiet=quiet,
            path="",
            shell=False,
            callback=callback,
            enhance_errors=flower.SETTINGS.get("enhance_errors", True)
        )


class FlowExecCommand(sublime_exec.ExecCommand):
    callback = noneCallback
    _output = None
    enhance_errors = True
    has_main = True

    def run(self, *args, **kwargs):
        self._output = StringIO("")
        self.callback = kwargs.pop('callback', self.callback)
        self.enhance_errors = kwargs.pop('enhance_errors', self.enhance_errors)
        super().run(*args, **kwargs)

    @staticmethod
    def processSemicolon(matchobj):
        """Fix wrong missing semicolon position"""
        file, row, col, msg = matchobj.groups()
        if msg != "Expected semi-colon":
            return matchobj.string

        view = sublime.active_window().find_open_file(file)
        row = max(0, int(row)-1)
        col = len(view.substr(view.line(view.text_point(row-1, 1))))+1
        return "{}:{}:{}: {}".format(file, row, col, msg)

    def check_main(self, data):
        """Whether file can be run"""
        warn = "WARNING: Program does not have 'main()'"
        if data.startswith(warn):
            self.has_main = False

    def preprocess(self, data):
        """Preprocess output"""
        self.check_main(data)
        if not (self.enhance_errors and data):
            return data
        return FILE_REGEX.sub(self.processSemicolon, data)

    def on_data(self, proc, data):
        out = self.preprocess(data)
        super().on_data(proc, out)
        if not self._output.closed:
            self._output.write(out)

    def finish(self, proc):
        super().finish(proc)
        content = self._output.getvalue()
        self._output.close()
        if not proc.exit_code() and self.has_main:
            self.callback(content)
        elif self.callback is not noneCallback:
            log.info("Callback skipped")
