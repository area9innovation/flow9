import os.path as op
import logging

import flower
from ..pathutils import getAbsPath
from ..env import expandEnv

log = logging.getLogger(flower.NAME)

# -----------------------------------------------
# FLOW.CONFIG & INCLUDES
# -----------------------------------------------

# Config search

CONFIG_PATH = "#path"
CONFIG_CACHE = {}

def _findConfig(dirpath):
    """Find flow.config file recursively in current directory & climbing up, caching everything"""
    try:
        return CONFIG_CACHE[dirpath]
    except KeyError:
        configpath = op.join(dirpath, 'flow.config')
        if op.exists(configpath):
            return CONFIG_CACHE.setdefault(dirpath, configpath)

        root = op.dirname(dirpath)
        if dirpath == root:  # this is the end
            return None

        return CONFIG_CACHE.setdefault(dirpath, _findConfig(root))


def findConfig(path):
    """Find applicable flow.config file for path, preferably in cache. May return None"""
    # prefer dirs to files, since neighbouring files will have same config
    dirpath = op.dirname(path) if op.splitext(path)[1] else path
    configpath = _findConfig(dirpath)
    return configpath


def configRoot(configpath, root=False):
    """Return directory path containing flow.config or flow[/lib] path"""
    if configpath is None:
        return flower.PATH['flow' if root else 'lib']
    return op.dirname(configpath)

#---------------------
# flow.config parsing
#---------------------

def _linesToConfig(lines, path="local"):
    """Parse text lines and return config dictionary"""
    config = dict(
        line.partition('=')[::2] for line in lines
        if not line.startswith("#")
    )
    config[CONFIG_PATH] = path
    return config


def _fileToConfig(path):
    """Parse config file and return config dictionary object"""
    if path is None:
        log.debug("C- No flow.config found, fallback to defaults")
        return {}

    with open(path) as c:
        lines = c.read().splitlines()

    return _linesToConfig(lines, path)


def _inlineToConfig(path):
    """Read prefixed lines from top of the file and treat them as flow.config content"""
    prefix = "//#"
    start = len(prefix)
    lines = []
    with open(path) as c:
        for line in c:
            if not line.startswith(prefix):
                break # read only top of the file
            lines.append(line[start:].strip())
    return _linesToConfig(lines, path)


#----------
# Includes
#----------

def _getConfigIncludes(config):
    """Get include option from config dictionary object and return set of include paths"""
    line = config.get('include')
    return set() if line is None else set(line.split(','))


def _normalizedIncludes(configpath):
    """Return map of normalized absolutepath includes from config file.
       Must include flow/lib for import lookup & linter"""
    root = configRoot(configpath)
    toFullPath = lambda p: getAbsPath(root, p)
    core_includes = (flower.PATH['lib'], root)
    includes = _getConfigIncludes(_fileToConfig(configpath))
    return map(toFullPath, set(core_includes) | set(includes))


def inlineIncludes(path):
    """Get inline includes for run executor"""
    return _getConfigIncludes(_inlineToConfig(path))


def allNormalizedIncludes(path, configpath=None):
    """Get all includes for specified file. For import lookup & linter"""
    configpath = configpath or findConfig(path)
    expand = lambda i: set(expandEnv(*i))
    config_includes = expand(_normalizedIncludes(configpath))
    inline_includes = expand(inlineIncludes(path))
    includes = config_includes | inline_includes
    # log.debug("All includes: %s", includes)
    return includes
