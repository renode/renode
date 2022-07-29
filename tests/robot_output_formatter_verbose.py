ROBOT_LISTENER_API_VERSION = 2

# callbacks
def start_suite(name, attrs):
    print("**** Starting suite '{}' with {} tests:{}".format(attrs["source"], attrs["totaltests"], attrs["tests"]))

def end_suite(name, attrs):
    print("**** Finished suite '{}' in {}ms: {}.".format(attrs["source"], attrs["elapsedtime"], attrs["statistics"]))

def start_test(name, attrs):
    print("+++++ Starting test '{}': ({}:{})".format(attrs["longname"], attrs["source"], attrs["lineno"]))

def end_test(name, attrs):
    print("+++++ Finished test '{}' in {}ms with status {}:{} ({}:{})".format(attrs["longname"], attrs["elapsedtime"], attrs["status"], attrs["message"], attrs["source"], attrs["lineno"]))

def end_keyword(name, attrs):
    if attrs["source"] == None or "renode-keywords.robot" in attrs["source"]:
        return

    print("{: <10} {: >6}ms  {}    {} ({}:{})".format(attrs["type"], attrs["elapsedtime"], attrs["kwname"], '  '.join(attrs["args"]), attrs["source"], attrs["lineno"]))
