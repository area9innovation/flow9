import re

import sublime

import flower
from .core import Runner
from .config import configRoot, allNormalizedIncludes, CONFIG_PATH
from ..pathutils import getParentName


DEFINITION_REGEX = re.compile(
    r"^.*\((?P<path>.*?):(?P<line>\d+)@(?P<bytes>\d+\-\d+)\)\s*\=\s*(?P<msg>[\w\W]+)",
    re.MULTILINE
)
DEFINITIONC_REGEX = re.compile(
    r"(?P<path>.*?):(?P<line>\d+):(?P<col>\d+):(?P<msg>[\w\W]+)(?=\d+\.\d+s)",
    re.MULTILINE
)


# father of all compilers
class Flow:
    cmd = ("flow",)
    config = {}
    configpath = None
    defn_regex = DEFINITION_REGEX

    def __str__(self):
        return "{} ({})".format(
            self.__class__.__name__,
            getParentName(self.configpath, depth=3)
        )

    def __init__(self, config):
        self.config = config
        self.configpath = config.pop(CONFIG_PATH, None)

    # "private" names that aren't listed as actions are "__"-suffixed

    @classmethod
    def isOld__(cls):
        return cls == Flow

    @classmethod
    def name__(cls, action):
        f = '{}.{}'.format(cls.__name__, action)
        return f if cls.isOld__() else '{} ({})'.format(f, Flow.__name__)

    @staticmethod
    def formatIncludes__(includes):
        """Return list of includes formatted for command"""
        return tuple(map("-I {}".format, includes))

    @classmethod
    def findDefinition__(cls):
        """Find definition"""
        return Runner(
            name=cls.name__('finddef'),
            cmd=Flow.cmd,
            options=(
                "--find-definition", "{token}",
            ),
            after='find'
        )

    def linter__(self, path):
        """Return linter command for SublimeLinter"""
        workdir = configRoot(self.configpath, root=True)
        includes = allNormalizedIncludes(path, configpath=self.configpath)
        cmd = (
            "{flowpath}/flowtools/bin/{platform}/flow"
            " --sublime --root {workdir} {includes} $file_on_disk"
        )
        return cmd.format(
            flowpath=flower.PATH['flow'],
            platform=sublime.platform().replace('osx', 'mac'),
            includes=' '.join(Flow.formatIncludes__(includes)),
            workdir=workdir,
        ).replace('\\', '/') # sublimelinter requires forward slashes

    # public names without underscore are treated as actions in manager.py

    @classmethod
    def compile(cls):
        """Compile/check specified flow file. Do not run"""
        return Runner(
            name=cls.name__('compile'),
            cmd=Flow.cmd,
            options=(
                "--compile", "{workpath}.bytecode",
                "--debuginfo", "{workpath}.debug",
            )
        )

    @classmethod
    def js(cls):
        """Compile specified file into js. Open in browser when done"""
        return Runner(
            name=cls.name__('js'),
            cmd=Flow.cmd,
            options=(
                "--js {binaryfolder}/{name}.js",
            ),
            after='web'
        )

    @classmethod
    def js_debug(cls):
        """Same as js, but compile debuggable js"""
        runner = cls.js()
        runner.options += (
            "--debug",
        )
        return runner

    @classmethod
    def cpp(cls):
        """Compile & run with byterunner"""
        runner = cls.compile()
        runner.after = 'cpp'
        return runner

    @classmethod
    def debug(cls):
        """Compile & run with byterunner in debug mode for SublimeGDB"""
        runner = cls.compile()
        runner.after = 'gdb'
        return runner


class Flowc(Flow):
    # We do it to be compliant with flowcpp behaviour. In future this may be removed
    cmd = ("flowc1",)
    defn_regex = DEFINITIONC_REGEX

    @staticmethod
    def formatIncludes__(includes):
        return includes and ("I={}".format(','.join(includes)),)

    @classmethod
    def findDefinition__(cls):
        return Runner(
            name=cls.name__('finddef'),
            cmd=cls.cmd,
            options=(
                "find-definition={token}",
            ),
            after='find'
        )

    def linter__(self, path=None):
        return "{exec} lint=1 $file_on_disk".format(exec=' '.join(self.cmd)).replace('\\', '/')

    # public

    @classmethod
    def compile(cls):
        return Runner(
            name=cls.name__('compile'),
            cmd=cls.cmd,
            options=(
                "bytecode={workpath}.bytecode",
                "debug=1",
            )
        )

    @classmethod
    def js(cls):
        return Runner(
            name=cls.name__('js'),
            cmd=cls.cmd,
            options=(
                "js={binaryfolder}/{name}.js",
            ),
            after='web'
        )

    @classmethod
    def js_debug(cls):
        runner = cls.js()
        runner.options += ("debug=1",)
        return runner


    @classmethod
    def cpp(cls):
        return super().cpp()

    @classmethod
    def debug(cls):
        return super().debug()
