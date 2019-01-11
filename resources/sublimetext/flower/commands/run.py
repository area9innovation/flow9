import logging
import os.path as op
from functools import partial
from itertools import chain

import sublime
import sublime_plugin

import flower
from . import manager
from .utils import rootSplit, getBinaryFolder
from .compilerutils import getCompiler, COMPILER_KEY
from .process import Executor, Callback, Default
from .config import inlineIncludes
from ..env import expandEnv, expandPath
from ..pathutils import getExt, getFileName, getName

log = logging.getLogger(flower.NAME)


def snake_to_camel(s, sep=' '):
    return '{}'.format(sep).join(map(str.capitalize, s.split('_')))


def option_keys(workdir, workpath, binaryfolder_):
    name, pathname = op.basename(workpath), op.join(workdir, workpath)
    binaryfolder = expandPath(binaryfolder_ or flower.ENV.get('binaryfolder'))
    return Default(
        name=name,
        pathname=pathname,
        workpath=workpath,
        binaryfolder=getBinaryFolder(binaryfolder, workdir),
    )


def meta_values(workdir):
    """Application is meta-app if we have root/(www2,flow.config,app)/app.flow"""
    www2 = op.join(workdir, 'www2')
    if op.exists(www2):
        root = op.basename(workdir)
        url = "http://${{localhost}}/{root}/flowjs.html?name={{name}}{{args}}".format(root=root)
        log.info("Meta app overrides")
        log.debug("binaryfolder: %s", www2)
        log.debug("url: %s", url)
        return www2, url
    return None, None


class RunFlow(sublime_plugin.TextCommand):
    """Interactive main menu (F8)"""

    @staticmethod
    def selectPreset(action=None, runner=None):
        """Select preset from menu and run action/runner, or select runner"""
        ext = runner and runner.ext
        presets = manager.getPresets(ext)
        onPreset = partial(RunFlow.get_run, action=action, runner=runner)

        if len(presets) == 1:
            onPreset(presets[0])
        else:
            items = [preset.toStr() for preset in presets]
            onDone = lambda i: i > -1 and onPreset(presets[i])
            sublime.active_window().show_quick_panel(items, onDone)

    @staticmethod
    def selectRunner(preset):
        """Select action/runner from menu for predefined preset"""
        if not preset:
            log.error("Can't select runner without preset")
            return

        ext = getExt(preset.main)
        actions = manager.getActions(ext)
        if not actions:
            log.error("No actions available for `%s` file", ext)
            return

        # compiler makes sense for .flow
        compiler = getCompiler(preset.main, key=COMPILER_KEY)
        runners = manager.getRunners(ext)

        wrap = lambda runner: partial(RunFlow.runCommand, preset, runner)
        action_pairs = ((snake_to_camel(a), wrap(getattr(compiler, a)())) for a in actions)
        runner_pairs = ((r.toStr()[0], wrap(r)) for r in runners)

        view = sublime.active_window().active_view()
        open_config = lambda: view.run_command("flower_open_config", {
            "configpath": compiler.configpath
        })

        misc_pairs = filter(lambda x: x[0], [
            (compiler.configpath and 'Configure {}'.format(compiler), open_config),
        ])

        names, commands = zip(*(chain(action_pairs, runner_pairs, misc_pairs)))

        onDone = lambda i: i > -1 and commands[i]()
        sublime.active_window().show_quick_panel(names, onDone)


    @staticmethod
    def execAction(preset, action, key=COMPILER_KEY, format_keys=None, after_args=()):
        runner, compiler = manager.actionToRunner(action, preset, key)
        RunFlow.execRun(preset, runner, compiler, format_keys, after_args)


    @staticmethod
    def execRun(preset, runner, compiler, format_keys=None, after_args=()):
        """Prepare all necessary bits for executing a command & go for it"""
        main = preset.main
        workdir, name = rootSplit(main)
        compiler = compiler or getCompiler(main)
        # regular includes retrieved from config, add inline ones
        includes = compiler.formatIncludes__(inlineIncludes(main))

        meta_binaryfolder, meta_url = meta_values(workdir)
        binaryfolder, url = preset.binaryfolder or meta_binaryfolder, preset.url or meta_url

        format_keys = format_keys or dict()
        # can't ChainMap Default-dict, so update
        format_keys.update(option_keys(workdir, getName(name), binaryfolder))
        expand_options = lambda option: option.format(**format_keys)

        cmd = expandEnv(*chain(
            runner.cmd,
            map(expand_options, runner.options),
            includes,
            [name],
        ))

        afterArgs = {
            "cpp": (workdir, getName(name), preset.args),
            "gdb": (workdir, name, preset.args),
            "web": (url, getFileName(name), preset.args),
            "find": (compiler.defn_regex,),
        }.get(runner.after, ()) + after_args

        Executor.run(
            cmd=cmd,
            workdir=workdir,
            after=Callback(runner.after, afterArgs),
            quiet=True
        )

    @staticmethod
    def runCommand(preset, runner, compiler=None):
        """Run specified preset with runner"""
        if not (preset and runner):
            return

        view = sublime.active_window().active_view()
        if view.is_dirty():
            view.run_command('save')

        manager.setRun(preset, runner)
        RunFlow.execRun(preset, runner, compiler)


    @staticmethod
    def get_preset(preset):
        """ preset: None = select, 'invalid' = current """
        if isinstance(preset, (type(None), manager.Preset)):
            return preset

        presets = tuple(filter(lambda p: p.key == preset.lower(), manager.getPresets()))
        if presets:
            got_preset = presets[0]
            log.debug("Preset: %s", got_preset)
        else:
            got_preset = manager.currentFilePreset()
            if preset:
                log.warning("Preset `%s` is not specified", preset)

        return got_preset


    @staticmethod
    def get_runner(runner, preset):
        if isinstance(runner, (type(None), manager.Runner)):
            return runner

        ext = preset and getExt(preset.main)
        runners = tuple(filter(lambda r: r.key == runner.lower(), manager.getRunners(ext)))
        if runners:
            got_runner = runners[0]
            log.debug("Runner: %s", got_runner)
        else:
            got_runner = None
            log.error("Runner `%s` is not specified", runner)

        return got_runner


    @staticmethod
    def get_run(preset=None, action=None, runner=None):
        got_preset = RunFlow.get_preset(preset)
        got_runner = RunFlow.get_runner(runner, got_preset)

        # nothing provided - select preset first
        if got_preset is None:
            RunFlow.selectPreset(action, got_runner)

        # action provided
        elif action is not None:
            runner_, compiler_ = manager.actionToRunner(action, got_preset)
            RunFlow.runCommand(got_preset, runner_, compiler_)

        # preset provided
        elif got_runner is None:
            RunFlow.selectRunner(got_preset)

        # preset & runner provided
        else:
            RunFlow.runCommand(got_preset, got_runner)


    def run(self, edit, preset=None, action=None, runner=None):
        return self.get_run(preset, action, runner)
