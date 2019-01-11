import re
import html
import logging
import os.path as op
import textwrap
from functools import partial
from collections import deque

import sublime
import sublime_plugin

import flower
from . import manager
from .run import RunFlow
from .utils import open_file
from .config import allNormalizedIncludes
from .compilerutils import FINDDEF_KEY
from .process import Default
from ..pathutils import newExt, getAbsPath, FLOW_EXT, isFlowFile

log = logging.getLogger(flower.NAME)

TOKEN_REGEX = re.compile(r"[A-z_][A-z0-9_]*")
IMPORT_REGEX = re.compile(r"^(\/[\*/]\s)?(forbid|import)\s(?P<path>\w.*);")
WRAP_REGEX = re.compile(r'(\{\}|\{|\}|;)')


# -----------------------------------------------
# PROCESSES & RUNNING
# -----------------------------------------------

def region_to_pos(region):
    return (region.a, region.b)


def pos_to_region(pos):
    return sublime.Region(*pos)


class FindDefinition(sublime_plugin.TextCommand):
    preset = None

    @staticmethod
    def getTokens(view):
        """Gather tokens from selected regions"""
        vsel = view.sel()
        points = set(region.begin() for region in vsel)
        vsel.clear()
        for p in points:
            vsel.add(sublime.Region(p, p))
        view.window().run_command("find_under_expand")

        imports, tokens = set(), dict()
        for region in vsel:
            if region.empty():
                continue

            line = view.substr(view.line(region))
            match = IMPORT_REGEX.match(line)
            if match is not None:
                imports.add(match.group('path'))
            else:
                token = view.substr(region).strip(':;,.\n\t {}[]()')
                if TOKEN_REGEX.match(token) is not None:
                    pos = tokens.setdefault(token, set())
                    pos.add(region_to_pos(region))
        return imports, tokens


    @staticmethod
    def lookupImport(importpath, includes=None):
        includes = includes or []
        path = newExt(importpath, FLOW_EXT)
        getFullPath = partial(getAbsPath, path=path)
        paths = tuple(map(getFullPath, includes))
        log.debug("Searching imports in %s", includes)

        for path in filter(op.exists, paths):
            log.debug("Found %s", path)
            sublime.set_timeout_async(partial(open_file, path))


    def lookupToken(self, tokendict):
        token, positions = tokendict
        keys = Default(token=token)

        def phantomize(msg, link):
            for pos in positions:
                self.view.run_command('phantom_manager', {
                    'pos': pos,
                    'msg': msg.strip(),
                    'link': link
                })

        RunFlow.execAction(
            preset=self.preset,
            action='findDefinition__',
            key=FINDDEF_KEY,
            format_keys=keys,
            after_args=(token, phantomize),
        )


    def process(self, imports, tokens):
        log_ = lambda s, v: v and log.info('Lookup %s: %s', s[:-(len(v) < 2) or None], ', '.join(v))

        log_('imports', imports)
        includes = allNormalizedIncludes(self.preset.main)
        for imp in imports:
            sublime.set_timeout_async(partial(self.lookupImport, imp, includes))

        log_('tokens', tokens.keys())
        for tokendict in tokens.items():
            sublime.set_timeout_async(partial(self.lookupToken, tokendict))


    def run(self, edit):
        self.preset = manager.currentFilePreset()
        if isFlowFile(self.preset.main):
            self.process(*self.getTokens(self.view))


class PhantomManager(sublime_plugin.TextCommand):
    style = '''
        <style>
            a {
                padding: 0 0.3rem;
                color: var(--background);
                background-color: var(--clr);
                text-decoration: inherit;
            }
            .pad { padding-left: 3.6rem }
            .padx { padding-left: 1.0rem }
            .dark { --clr: var(--greenish) }
            .light { --clr: var(--purplish) }
            .defn {
                padding: 0;
                line-height: 1.5em;
                padding-right: 0.3rem;
                border: 1px solid var(--clr)
            }
            .link { color: inherit; background-color: inherit; }
        </style>
    '''

    def __init__(self, *args, **kwargs):
        super().__init__(*args, **kwargs)
        self.phantomSet = sublime.PhantomSet(self.view, 'finddef')

    @staticmethod
    def split(msg, length=70):
        res = []
        a = b = 0
        while True:
            b = msg.rfind('|', a, a + length)
            if b == a:
                res[-1] += msg[a:]
                break
            res.append(msg[a:b])
            a = b
        return res

    @classmethod
    def wrap(cls, msg):
        sub = {
            '\t': '<span class="pad">&nbsp;</span>',
            '\r': '<span class="padx">&nbsp;</span>',
            '\n': '<br>'
        }
        regex = re.compile('|'.join(map(re.escape, sub.keys())))
        escape = lambda s: html.escape(''.join(s), quote=False)
        replace = lambda s: regex.sub(lambda match: sub[match.group(0)], s)

        res = deque()
        line = deque()
        indent = 0
        append = lambda line, part=0: line and res.extend([
            '\t'*bool(indent),
            '\r'*(indent+part),
            escape(line),
            '\n'
        ])

        for token in WRAP_REGEX.split(msg):
            t = token.lstrip()
            if not t:
                continue

            if t == ';':
                line.append(t)
                append(line)
                line.clear()
            elif t == '{':
                line.append(t)
                append(line)
                line.clear()
                indent += 1
            elif t == '}':
                append(line)
                line.clear()
                line.append(t)
                indent -= 1
            else: # text
                lines = cls.split(t) if '|' in t else textwrap.wrap(t, width=100)
                if len(lines) > 1:
                    for i, p in enumerate(lines):
                        append(p, part=bool(i))
                else:
                    line.append(t)

        res.append(escape(line))
        return replace(''.join(res))


    def addPhantom(self, pos, msg, link):
        links = [
            ('hideall', chr(0x1F53B)),
            ('hide', chr(0x1F53D)),
            ('paste', chr(0x1F4CB)),
            ('link', self.wrap(msg)),
        ]

        content = '<body id="flow-defn">{style}<div class="defn">{links}</div></body>'.format(
            style=self.style,
            links=''.join('<a class="{0}" href={0}>{1}</a>'.format(*link) for link in links)
        )

        region = pos_to_region(pos)
        phantom = sublime.Phantom(region, content, sublime.LAYOUT_BLOCK)
        phantom.on_navigate = partial(self.navigatePhantom, phantom=phantom, msg=msg, link=link)

        phantoms = self.phantomSet.phantoms + [phantom]
        self.phantomSet.update(phantoms)


    def navigatePhantom(self, href, phantom, msg, link):
        if href == "hideall":
            self.phantomSet.update([])

        elif href == "hide":
            self.erase_phantom(phantom)

        elif href == "paste":
            pos = region_to_pos(phantom.region)
            self.view.run_command('paste_definition', {'msg': msg, 'pos': pos})
            self.erase_phantom(phantom)

        elif href == "link":
            sublime.set_timeout_async(lambda: open_file(link, sublime.ENCODED_POSITION), 10)

    def erase_phantom(self, phantom):
        self.view.erase_phantom_by_id(phantom.id)
        self.phantomSet.update(self.phantomSet.phantoms)


    def run(self, edit, pos, msg, link):
        inline = flower.SETTINGS.get("inline_definitions", True)
        if inline:
            self.addPhantom(pos, msg, link)
        else:
            self.navigatePhantom("link", None, msg, link)


class PasteDefinition(sublime_plugin.TextCommand):
    def run(self, edit, msg, pos):
        region = pos_to_region(pos)
        line = self.view.line(region)
        indent = '\n'+re.split(r'\w', self.view.substr(line))[0]
        self.view.insert(edit, line.end(), indent + msg)
