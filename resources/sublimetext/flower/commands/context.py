import sublime
import sublime_plugin

from .utils import rootSplit, open_file, findConfig
from ..pathutils import getName, isFlowFile


class FlowerCopyImport(sublime_plugin.TextCommand):

    def run(self, edit):
        _, name = rootSplit(self.view.file_name())
        main = getName(name)
        if main:
            sublime.set_clipboard("import {};".format(main))

    def is_enabled(self):
        return isFlowFile(self.view.file_name())


class FlowerOpenConfig(sublime_plugin.TextCommand):

    def run(self, edit, configpath=None):
        configpath = configpath or findConfig(self.view.file_name())
        if configpath:
            sublime.set_timeout_async(lambda f=configpath: open_file(f))

    def is_enabled(self):
        return isFlowFile(self.view.file_name())
