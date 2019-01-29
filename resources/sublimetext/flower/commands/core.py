import logging

import flower
from ..pathutils import FLOW_EXT, getFileName
from ..env import expandEnv, expandPath

log = logging.getLogger(flower.NAME)

class Entity:
    allowed = ()
    key = "entity"

    def __repr__(self):
        return (
            "{}({{key}}, {{{}}})"
            .format(self.__class__.__name__, '}, {'.join(self.allowed))
            .format(**self.__dict__)
        )

    def __str__(self):
        return str(self.key)

    def __init__(self, **kwargs):
        self.name = "normalized entity"
        for key in self.allowed:
            setattr(self, key, kwargs.get(key))
        self.normalize(self.key)

    @classmethod
    def _empty(cls):
        return cls(**dict.fromkeys(cls.allowed, "")).__dict__

    def normalize(self, name):
        if self.name is None:
            self.name = name
        self.key = self.name.lower()

    @classmethod
    def fromdict(cls, d):
        df = {k: v for k, v in d.items() if k in cls.allowed}
        return cls(**df)


class Preset(Entity):
    allowed = ('name', 'main', 'imports', 'args', 'binaryfolder', 'url')

    def normalize(self, _):
        if self.main:
            self.main = expandPath(self.main)
            self.imports = expandEnv(*self.imports) if self.imports else ()
            self.args = tuple(self.args or [])
            super().normalize(getFileName(self.main).title())

    def toStr(self):
        return '{name}\nFile: {main}\nArgs: {args}'.format(
            name=self.name.replace('\\', '/'),
            main=self.main,
            args=" ".join(self.args),
        ).splitlines()


class Runner(Entity):
    allowed = ('name', 'cmd', 'options', 'ext', 'after')
    cmd = 'flow'

    def normalize(self, _):
        cmd = (self.cmd,) if hasattr(self.cmd, 'lower') else self.cmd
        self.cmd = expandEnv(*cmd)
        self.options = self.options or ()  # expand options from runner
        self.ext = tuple(e.lower() for e in self.ext or [FLOW_EXT])
        super().normalize(self.cmd[0])

    def toStr(self):
        return "{name}\nCmd: {cmd} {options}".format(
            name=self.name,
            cmd=self.cmd,
            options=" ".join(self.options),
        ).splitlines()
