# -*- coding: utf-8 -*-
# flow.py - sublimelint package for checking flow files

import re

from base_linter import BaseLinter, INPUT_METHOD_TEMP_FILE

CONFIG = {
    'language': 'flow',
    'executable': 'lint.bat',
#    'executable': '/Users/asgerottaralstrup/copenhagen/flow/lint.sh',
    'input_method': INPUT_METHOD_TEMP_FILE
}


class Linter(BaseLinter):
    def parse_errors(self, view, errors, lines, errorUnderlines, violationUnderlines, warningUnderlines, errorMessages, violationMessages, warningMessages):
        for line in errors.splitlines():
            match = re.match(r"^(?:ERROR: )?(?P<file>...*?):(?P<line>[0-9]*):?([0-9]*)(?P<error>.*)", line)
            if match:
                error, line2 = match.group('error'), match.group('line')
                if line2 != "":
                    self.add_message(int(line2), lines, error, errorMessages)

    def get_lint_args(self, view, code, filename):
        args = [filename]
        return args
