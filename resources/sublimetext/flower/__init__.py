import os
import sys

import sublime

NAME = 'flower'
PATH = {'q': os.path.join('flow9', 'bin')}
SETTINGS = {}
ENV = {}

readme = os.path.join(os.path.dirname(__file__), "README.md")
with open(readme, encoding='utf-8') as f:
    VERSION = f.readline().rpartition(' ')[-1].strip('(\n)`')

def is_windows():
    return sublime.platform() == "windows"

# Add flowbin to sys.path from PATH in case it's not seen by sublime (usually on windows)
# Also required by linter
try:
    binpath = next(
        x for x in os.environ['PATH'].split(os.pathsep)
        if PATH['q'] in x
    )
except StopIteration:
    # nothing can be done here yet, show message in plugin_loaded
    pass
else:
    if binpath not in sys.path:
        sys.path.append(binpath)

    flowpath = os.path.dirname(binpath)
    repopath = os.path.dirname(flowpath)
    home = 'C:/' if is_windows() else os.path.expanduser('~/')
    PATH = {
        'repo': repopath,
        'flow': flowpath,
        'bin': binpath,
        'lib': os.path.join(flowpath, 'lib'),
    }
    # default values for vital parameters
    VITALS = {
        'repo': repopath or home,
        'binaryfolder': os.path.join(flowpath, 'www'),
        'localhost': 'localhost',
    }
finally:
    # Load commands - after all other initialization
    print("Importing commands")
    from .commands import *
