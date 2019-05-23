import gdb

from gdb.FrameDecorator import FrameDecorator
from gdb.unwinder import Unwinder

import re
import bisect

def debug(something):
	print(something)
	pass

class FlowMemoryRangeInfo(object):
	def __init__(self):
		self.memory_ranges = None
		self.symcache = {}
		self.version = 0
		gdb.events.cont.connect(self.invalidate_unwinder_state)

	def invalidate_unwinder_state(self, *args, **kwargs):
		#self.memory_ranges = None
		self.symcache = {}
		#self.version = 0

	def get_mem_ranges(self):
		version_ptr = gdb.lookup_global_symbol('flow_gdb_memory_layout_version')

		if self.memory_ranges is not None:
			if not version_ptr or int(version_ptr.value()) == self.version:
				return self.memory_ranges

		ranges = self.memory_ranges = []

		self.symcache = {}
		self.version = int(version_ptr.value())

		range_table = gdb.lookup_global_symbol('flow_gdb_memory_layout')
		if range_table is None:
			return self.memory_ranges

		cur = range_table.value()
		debug("@@ range ptr %x" % (cur))
		while cur != 0:
			debug("@@ range %x..%x" % (cur["start"], cur["end"]))

			psym = cur["symbols"]
			symbols = []
			symaddr = []

			for i in range(0, int(cur["num_symbols"])):
				psymi = psym[i]
				ptr = int(psym[i]["addr"])
				name = psym[i]["name"].string()
				debug("@@@ addr %x: %s" % (ptr, name))
				symbols.append((ptr, name))
				symaddr.append(ptr)

			ranges.append((cur["start"], cur["end"], symbols, symaddr))
			cur = cur["next"]

		return ranges

	def find_symbol(self, pc):
		ranges = self.get_mem_ranges()

		if pc in self.symcache:
			return self.symcache[pc]

		found = None

		for r in ranges:
			if r[0] <= pc < r[1]:
				i = bisect.bisect_right(r[3], int(pc))
				sym = r[2][i-1] if i else (r[0], None)
				#debug("@@@ flow sym %x %x %x %s" % (r[0], r[1], sym[0], sym[1]))
				found = (r[0], r[1], sym[0], sym[1])
				break

		self.symcache[pc] = found
		return found

class FlowFrameDecorator(FrameDecorator):
	def __init__(self, fobj, sym):
		super(FlowFrameDecorator, self).__init__(fobj)
		self.sym = sym

	def function(self):
		return self.sym[3]

class FlowFrameFilter():
	def __init__(self, info):
		self.name = "FlowFrameFilter"
		self.priority = 100
		self.enabled = True
		self.info = info

	def decorate(self, frame):
		pc = frame.inferior_frame().pc()
		sym = self.info.find_symbol(pc)
		if sym:
			return FlowFrameDecorator(frame, sym)
		else:
			return frame

	def filter(self, frame_iter):
		#debug("@@ frame filter")
		frame_iter = map(self.decorate, frame_iter)
		return frame_iter

class FlowFrameId(object):
	def __init__(self, sp, pc):
		self.sp = sp
		self.pc = pc

class Flow64Unwinder(Unwinder):
	def __init__(self, info):
		super(Flow64Unwinder, self).__init__("SpiderMonkey")
		self.info = info

	ENTRY_REGS = [ 'r15', 'r14', 'r13', 'r12', 'rdi', 'rsi', 'rbx', 'rbp', 'rip' ]
	FLOW_REGS = [ 'r11', 'r15', 'r14', 'rip' ]
	PASS_REGS = [ 'r13', 'r12', 'rbx', 'rbp' ]

	def unwind_frame(self, pending_frame, basereg, reglist, passregs=[]):
		bp = pending_frame.read_register(basereg)

		void_starstar = gdb.lookup_type('void').pointer().pointer()
		sp = bp.cast(void_starstar) - (len(reglist)-2)

		regs = {}

		for reg in passregs:
			regs[reg] = pending_frame.read_register(reg)

		for reg in reglist:
			data = sp.dereference()
			sp = sp + 1
			regs[reg] = data
			if reg is basereg:
				regs['rsp'] = sp

		frame_id = FlowFrameId(regs['rsp'], regs['rip'])
		unwind_info = pending_frame.create_unwind_info(frame_id)
		debug("@@ sym @ %s" % str(regs['rip']))

		for reg in regs:
			debug("@@ unwinding %s => 0x%x" % (reg, regs[reg]))
			unwind_info.add_saved_register(reg, regs[reg])

		return unwind_info

	def __call__(self, pending_frame):
		pc = pending_frame.read_register('rip')
		sym = self.info.find_symbol(pc)
		if sym is None:
			return None

		debug("@@ unwinding %x" % (pc))

		if sym[3] is None or sym[3] == '$entry_thunk':
			return self.unwind_frame(pending_frame, 'rbp', self.ENTRY_REGS)
		else:
			return self.unwind_frame(pending_frame, 'r14', self.FLOW_REGS, self.PASS_REGS)


def register_unwinder(objfile):
	info = FlowMemoryRangeInfo()

	ffilter = FlowFrameFilter(info)
	gdb.frame_filters[ffilter.name] = ffilter

	unwinder = Flow64Unwinder(info)
	gdb.unwinder.register_unwinder(objfile, unwinder, replace=True)

register_unwinder(None)
