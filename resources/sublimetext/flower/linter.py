import logging

from SublimeLinter.lint import Linter, util

import flower
from .commands.compilerutils import getCompiler, LINTER_KEY

log = logging.getLogger(flower.NAME)

class Flow(Linter):
    """Provides an interface to flow."""
    defaults = {'selector': 'source.flow'}
    regex = r"(?P<file>\S+?):(?P<line>\d+):?(?P<col>\d+)?:? (?P<message>[^\/]+$)"
    line_col_base = (1, 1)
    multiline = True
    tempfile_suffix = "-"
    error_stream = util.STREAM_STDOUT

    def cmd(self):
        """Return a list with the command line to execute."""
        path = self.filename
        compiler = getCompiler(path, key=LINTER_KEY)
        self.multiline = not compiler.isOld__()
        log.debug("Compiler: %s", compiler)
        return compiler.linter__(path)
