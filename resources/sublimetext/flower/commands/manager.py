import logging
from itertools import chain

import sublime

import flower
from .core import Preset, Runner
from .compilerutils import getCompiler, Flow, COMPILER_KEY
from ..pathutils import isFlowFile, getExt, FLOW_EXT

log = logging.getLogger(flower.NAME)

_PRESET = None
_RUNNER = None
_ACTION = None


PRESETS = {
    "CURRENT": lambda: Preset(
        name='Current File',
        main=sublime.active_window().active_view().file_name(),
    )
}

RUNNERS = {}

# private stuff

def _getPreset(key):
    if isinstance(key, dict):
        return Preset.fromdict(key)

    preset = PRESETS.get(key)
    if callable(preset):
        return preset()
    return preset


def _setPreset(preset):
    global _PRESET
    log.debug('Preset: [%s] > [%s]', _PRESET, preset)
    _PRESET = preset


def _getRunner(key):
    if isinstance(key, dict):
        return Runner.fromdict(key)
    return RUNNERS.get(key)


def _setRunner(runner):
    global _RUNNER
    log.debug('Runner: [%s] > [%s]', _RUNNER, runner)
    _RUNNER = runner


# public stuff

def currentFilePreset():
    return PRESETS.get("CURRENT")()


def setRun(preset, runner):
    _setPreset(preset)
    _setRunner(runner)


def getPresets(exts=None):
    # force current
    presets = chain(
        (currentFilePreset(),),
        map(_getPreset, flower.SETTINGS.get('presets', []))
    )

    filterExt = lambda preset: (
        getExt(preset.main) in exts
        if exts is not None
        else True
    )

    filterFn = lambda preset: (
        preset.key is not None and
        preset.main is not None and
        filterExt(preset)
    )
    return tuple(filter(filterFn, presets))


def getRunners(ext=None):
    runners = (_getRunner(d) for d in flower.SETTINGS.get('runners', []))
    # disable filter if ext is None - get all
    filterFn = lambda runner: ext is None or (
        runner is not None
        and ext in runner.ext
        and runner.key is not None
        and runner.cmd is not None
    )
    return tuple(filter(filterFn, runners))


def getActions(ext=None, showSpecial=False):
    if ext in (None, FLOW_EXT):
        isAction = lambda func: not func.endswith("__") or showSpecial
        isListed = lambda func: not func.startswith("__") and isAction(func)
        filterFn = lambda func: callable(getattr(Flow, func)) and isListed(func)
        return tuple(filter(filterFn, dir(Flow)))
    return ()


# TODO: set compiler for action-presets
def actionToRunner(action, preset, key=COMPILER_KEY):
    if not isFlowFile(preset.main):
        log.debug("Can't perform `%s` action on `%s` file", action, preset.main)
        return (None, None)

    if action not in getActions(showSpecial=True):
        log.error("Unknown action `%s`", action)
        return (None, None)

    compiler = getCompiler(preset.main, key)
    log.debug("Action: %s", action)
    runner = getattr(compiler, action)()
    return runner, compiler
