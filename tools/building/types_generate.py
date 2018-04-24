#!/usr/bin/python
# Maximum number of parameters in function
max_params = 3

# Dictionary: key is the C# type, value - a C one
types = {}
types["Int32"] = "int32_t"
types["UInt32"] = "uint32_t"
types["IntPtr"] = "void *"
types["String"] = "char *"
types["UInt64"] = "uint64_t"

import itertools

typedefs = []
csharpdefs = []
rets = []
vars = []
args = []
keywords = []
typedef_to_delegates = {}

def make_delegate_name(args, return_type):
	return ("Action" if return_type == "void" else "Func%s" % return_type) + ("" if not args else reduce(lambda x, y: x + y, args))

def make_csharp_def(args, return_type):
	cs_name = make_delegate_name(args, return_type)
	number_iterator = range(i).__iter__()
	cs_args = map(lambda x: "%s param%d" % (x, number_iterator.next()), args)
	csharpdef = "[UnmanagedFunctionPointer(CallingConvention.Cdecl)]\npublic delegate %s %s(%s);" % (return_type, cs_name, "" if not cs_args else reduce(lambda x, y: x + ", " + y, cs_args))
	attacherdef = "[UnmanagedFunctionPointer(CallingConvention.Cdecl)]\npublic delegate void Attach%s(%s param);" % (cs_name, cs_name)
	return (csharpdef, attacherdef)

def make_typedef_name(args, return_type):
	return ("action" if return_type == "void" else "func_%s" % return_type.lower()) + ("" if not args else ("_" + reduce(lambda x, y: x + "_" + y, map(lambda t: t.lower(), args))))

def make_c_def(args, return_type):
	c_name = make_typedef_name(args, return_type)
	if(c_name.endswith("_")):
		c_name = c_name[0:len(c_name)-1]
	c_args = map(lambda x: types[x], args)
	typedef = "typedef %s (*%s)(%s);" % ("void" if return_type == "void" else types[return_type], c_name, "void" if not c_args else reduce(lambda x, y: x + ", " + y, c_args))
	return typedef

for i in range(1, max_params + 1):
	product = itertools.product(types, repeat = i)
	# C# delegate definition
	for p in product:
		# actions first
		typedefs.append(make_c_def(p, "void"))
		csharpdefs.append(make_csharp_def(p, "void"))
                typedef_name = make_typedef_name(p, "void")
		typedef_to_delegates[typedef_name] = make_delegate_name(p, "void")
		keywords.append("#define %s_keyword$"%typedef_name)
                rets.append("#define %s_return$ void"%typedef_name)
                vars.append("#define %s_vars$ %s"%(typedef_name, ', '.join([chr(x + 97) for x in range(0, len(p))])))
                args.append("#define %s_args$ %s"%(typedef_name, ', '.join([str("%s %c"%(types[p[x]], chr(x + 97))) for x in range(0, len(p))])))
		# functions then
		for t in types:
                        typedef_name = make_typedef_name(p, t)
			typedefs.append(make_c_def(p, t))
			csharpdefs.append(make_csharp_def(p, t))
			typedef_to_delegates[typedef_name] = make_delegate_name(p, t)
		        keywords.append("#define %s_keyword$ return"%typedef_name)
                        vars.append("#define %s_vars$ %s"%(typedef_name, ', '.join([chr(x + 97) for x in range(0, len(p))])))
                        rets.append("#define %s_return$ %s"%(typedef_name, types[t]))
                        args.append("#define %s_args$ %s"%(typedef_name, ', '.join([str("%s %c"%(types[p[x]], chr(x + 97))) for x in range(0, len(p))])))
# and the special case, function and action with no args TODO
typedefs.append(make_c_def([], "void"))
typedef_to_delegates["action"] = "Action"
keywords.append("#define action_keyword$")
rets.append("#define action_return$ void")
vars.append("#define action_vars$ ")
args.append("#define action_args$ ")
# C# has predefined Action, but not the attacher
csharpdefs.append(("", "[UnmanagedFunctionPointer(CallingConvention.Cdecl)]\npublic delegate void AttachAction(System.Action param);"))
for t in types:
        typedef_name = make_typedef_name([], t)
	typedefs.append(make_c_def([], t))
	csharpdefs.append(make_csharp_def([], t))
	typedef_to_delegates[typedef_name] = make_delegate_name([], t)
        keywords.append("#define %s_keyword$ return"%typedef_name)
        rets.append("#define %s_return$ %s" % (typedef_name, types[t]))
        vars.append("#define %s_vars$ " % typedef_name)
        args.append("#define %s_args$ " % typedef_name)

for key in typedef_to_delegates:
	print "#define RENODE_EXT_TYPE_%s %s" % (key,typedef_to_delegates[key])

for t in typedefs:
	print t

for r in rets:
        print r

for k in keywords:
        print k

for v in vars:
        print v

for a in args:
        print a

print ""
print "---------------------------------"
print ""

for (d, a) in csharpdefs:
	print d
	print a
