import logging
from pprint import pformat

import sublime

import flower
from .env import getEnv

# -----------------------------------------------
# PLUGIN LOAD
# -----------------------------------------------

def plugin_loaded():
    binpath = flower.PATH.get('bin')
    if binpath is None:
        sublime.message_dialog(
            "{}:\nIt seems that '{}' path is not set in OS environment PATH. "
            "Please check and try again".format(flower.NAME, flower.PATH.get('q', binpath))
        )

    if not flower.SETTINGS:
        flower.SETTINGS = sublime.load_settings("{}.sublime-settings".format(flower.NAME))
        flower.ENV = getEnv()

        log = init_logging(
            statusbar=flower.SETTINGS.get("statusbar", True),
            debug=flower.SETTINGS.get("debug", False)
        )
        log.debug("Paths:\n%s", pformat(flower.PATH))
        log.debug("ENV:\n%s", pformat(flower.ENV))

        version = '{} loaded, v.{}'.format(flower.NAME, flower.VERSION)
        fstr = '{}{{}}{}{{}}'.format(" " * 27, "─" * (len(version) + 2))
        print(fstr.format(*'┌┐'))
        log.info("│ %s │", version)
        print(fstr.format(*'└┘'))


def init_logging(statusbar=True, debug=False):
    log = logging.getLogger(flower.NAME)
    log.propagate = False
    log.setLevel(logging.DEBUG if debug else logging.INFO)

    while log.handlers:
        log.handlers.pop()

    fmt = lambda f: logging.Formatter(
        '[%(name)s] {0}%(message)s'.format(['', '%(asctime)s %(module)s|%(levelno)s: '][f]),
        '%H:%M:%S'
    )

    stream = logging.StreamHandler()
    stream.setFormatter(fmt(True))
    log.addHandler(stream)

    if statusbar:
        status = SublimeHandler()
        status.setFormatter(fmt(False))
        log.addHandler(status)

    log.debug("Logger initialized")
    return log

# -------------------------------------
# Sublime status bar logger
# -------------------------------------

class SublimeHandler(logging.Handler):
    def __init__(self):
        logging.Handler.__init__(self)
        self.setLevel(logging.INFO)

    def emit(self, record):
        try:
            views = sublime.active_window().views()
        except AttributeError:
            pass  # no view yet
        else:
            msg = self.format(record)
            for view in views:
                view.set_status(flower.NAME, msg)
