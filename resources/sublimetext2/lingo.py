# -*- coding: utf-8 -*-
# flow.py - sublimelint package for checking flow files

import re

from base_linter import BaseLinter, INPUT_METHOD_TEMP_FILE

CONFIG = {
    'language': 'lingo',
    'executable': 'lingolint.bat',
    'input_method': INPUT_METHOD_TEMP_FILE
}


class Linter(BaseLinter):
    def parse_errors(self, view, errors, lines, errorUnderlines, violationUnderlines, warningUnderlines, errorMessages, violationMessages, warningMessages):
        for line in errors.splitlines():
            match = re.match(r"^(?:ERROR: )?(?P<file>...*?):(?P<line>[0-9]*):?([0-9]*)(?P<error>.*)", line)
            if match:
                error, line = match.group('error'), match.group('line')
                lineno = int(line)

                self.add_message(lineno, lines, error, errorMessages)

    def get_lint_args(self, view, code, filename):
        args = [filename]
        return args
