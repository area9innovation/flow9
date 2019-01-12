import os
from collections import ChainMap

from sublime import expand_variables

import flower

# -----------------------------------------------
# ENV
# -----------------------------------------------

def expandStr(value):
    """Expand ${name}s and $NAMEs. Empty string if key not found"""
    return expand_variables(os.path.expandvars(value), flower.ENV)


def expandEnv(*items):
    """[do, $things] -> (do, env.things)"""
    res = tuple(filter(bool, map(expandStr, items)))
    return res


def expandPath(path):
    return os.path.normpath(os.path.expanduser(expandStr(path)))


def _recExpand(envdict):
    expanded = {key : expand_variables(val, envdict) for key, val in envdict.items()}
    return expanded if expanded == envdict else _recExpand(expanded)


def _getOSEnv():
    """Get variables dict for OS Envvars mentioned in config"""
    envlist = set(flower.SETTINGS.get('osenv', []))
    envdict = {}
    for key in envlist:
        value = os.getenv(key)
        if value is None:
            continue
        envdict[key.lower()] = value
    return envdict


def getEnv():
    get = lambda val, default: default if val == "auto" else val
    vitals = {k : get(flower.SETTINGS.get(k, "auto"), v) for k, v in flower.VITALS.items()}
    custom = flower.SETTINGS.get('vars', {}) # override os env
    return _recExpand(ChainMap(vitals, custom, _getOSEnv()))
