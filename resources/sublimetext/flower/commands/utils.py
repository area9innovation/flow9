import logging
import os.path as op

import sublime

import flower
from .config import findConfig, configRoot

log = logging.getLogger(flower.NAME)

def _relSplit(child, parent, split=True):
    """ (a/b/c/d, a/b) -> (a/b, c/d)
        (a/b/c/d, e/f) -> (a/b/c, d) | ('', a/b/c/d)
    """
    if child.lower().startswith(parent.lower()):
        return parent, op.relpath(child, parent)
    return op.split(child) if split else ('', child) # not relative

def getBinaryFolder(binaryfolder, workdir):
    _, child = _relSplit(binaryfolder, workdir, split=False)
    return child


def rootSplit(path):
    """ a/b/(conf,d)/e/flow -> (a/b, d/e/flow) """
    root = configRoot(findConfig(path))
    return _relSplit(path, root)


def open_file(*args):
    sublime.active_window().open_file(*args)
