import os.path as op
import tempfile

# -----------------------------------------------
# FILEPATH UTILS
# -----------------------------------------------

FLOW_EXT = 'flow'

def isFlowFile(path):
    return bool(path) and (getExt(path) == FLOW_EXT)


def getAbsPath(root, path):
    """op.join return path if it is absolute"""
    return op.abspath(op.join(root, path))


def getParentName(path, depth=2):
    """trash/folder/program.flow -> folder/program.flow"""
    if path is None:
        return ''
    return op.join(*path.split(op.sep)[-depth:])


def getFileName(path):
    """folder/program.flow -> program"""
    return getName(op.basename(path))


def getName(path):
    """folder/program.flow -> folder/program"""
    return op.splitext(path)[0]


def getExt(path):
    """folder/program.flow -> flow"""
    return op.splitext(path)[1].lstrip('.')


def newExt(path, ext):
    """folder/program.flow -> folder/program.ext"""
    return '.'.join([getName(path), ext])


def getTempName(path, ext=None):
    """folder/program.flow -> temp/program.ext"""
    fname = getFileName(path)
    if ext is not None:
        fname = newExt(fname, ext)
    return op.join(tempfile.gettempdir(), fname)


def getBytecodeDebugTemp(name='run', temp=True):
    """run -> (run.bytecode, run.debug)"""
    fn = getTempName if temp else newExt
    return [fn(name, s) for s in ('bytecode', 'debug')]


def getBytecodeDebug(path, name):
    """run -> (debug/run.bytecode, debug/run.debug)"""
    fn = lambda suffix: op.join(path, newExt(name, suffix))
    return map(fn, ('bytecode', 'debug'))
