#!/usr/bin/python
# Maximum number of parameters in function
max_params = 4

# Dictionary: key is the C# type, value - a C one
types = {}
types["Int32"] = "int32_t"
types["UInt32"] = "uint32_t"
types["IntPtr"] = "void *"
types["String"] = "char *"
types["UInt64"] = "uint64_t"

import itertools

csharpdefs = []

def make_delegate_name(args, return_type):
	return ("Action" if return_type == "void" else "Func%s" % return_type) + ("" if not args else reduce(lambda x, y: x + y, args))

def make_csharp_def(args, return_type):
	cs_name = make_delegate_name(args, return_type)
	number_iterator = range(i).__iter__()
	cs_args = map(lambda x: "%s param%d" % (x, number_iterator.next()), args)
	csharpdef = "[UnmanagedFunctionPointer(CallingConvention.Cdecl)]\npublic delegate %s %s(%s);" % (return_type, cs_name, "" if not cs_args else reduce(lambda x, y: x + ", " + y, cs_args))
	attacherdef = "[UnmanagedFunctionPointer(CallingConvention.Cdecl)]\npublic delegate void Attach%s(%s param);" % (cs_name, cs_name)
	return (csharpdef, attacherdef)


for i in range(1, max_params + 1):
	product = itertools.product(types, repeat = i)
	# C# delegate definition
	for p in product:
		# actions first
		csharpdefs.append(make_csharp_def(p, "void"))
		# functions then
		for t in types:
			csharpdefs.append(make_csharp_def(p, t))
# C# has predefined Action, but not the attacher
csharpdefs.append(("", "[UnmanagedFunctionPointer(CallingConvention.Cdecl)]\npublic delegate void AttachAction(System.Action param);"))
for t in types:
	csharpdefs.append(make_csharp_def([], t))


for (d, a) in csharpdefs:
	print d
	print a
