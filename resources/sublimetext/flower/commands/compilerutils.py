import re
import logging

import flower
from .compiler import Flow, Flowc
from .config import findConfig, _fileToConfig

log = logging.getLogger(flower.NAME)

COMPILER_KEY = 'compiler'
LINTER_KEY = 'linter'
FINDDEF_KEY = 'finddef'


def _getOverride(key):
    value = flower.SETTINGS.get("overrides", {}).get(key)
    return {"old": Flow, "new": Flowc}.get(value)


def _getConfigCompiler(config, key):
    """Get flowcompiler option from config dictionary object and return Compiler object"""
    compiler_override = _getOverride(key)
    if compiler_override is not None:
        log.warning("Override %s with %s", key, compiler_override.__name__)
        return compiler_override(config)

    default = Flow
    compiler = config.get('flowcompiler', 'flow')

    if re.match(r'flowc1?\b', compiler):
        return Flowc(config)

    if compiler == 'flow':
        return Flow(config)

    log.error(
        "Compiler `%s` is not supported, fallback to default %s",
        compiler, default.__name__
    )
    return default(config)


def _flowConfigCompiler(configpath, key):
    """Get Compiler object from flow.config"""
    config = _fileToConfig(configpath)
    compiler = _getConfigCompiler(config, key)
    return compiler


def getCompiler(path, key=COMPILER_KEY):
    """Get Compiler object from preset main file"""
    configpath = findConfig(path)
    compiler = _flowConfigCompiler(configpath, key)
    return compiler
