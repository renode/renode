import sys

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

def message(msg):
    """
    Called when the framework itself writes a syslog message.
    """
    # As robotframework is capturing sys.stdout and sys.stderr to log messages (as INFO level), this
    # message is written to the real stdout to avoid recalling this function and adding another
    # prefix to 'message'
    print('--- ' + msg['level'] + ': ' + msg['message'], file=sys.__stdout__)

def log_message(msg):
    """
    Called when an executed keyword writes a log message.
    """

    # As robotframework is logging WARN and ERROR messages to syslog too (tested on 6.1 and 7.5),
    # message(msg) will be called. To avoid duplicated those messages, there is nothing to do here
    # for those levels.
    if msg['level'] in ['ERROR', 'WARN']:
        return

    # As robotframework is capturing sys.stdout and sys.stderr to log messages (as INFO level), this
    # message is written to the real stdout to avoid recalling this function and adding another
    # prefix to 'message'
    print('--- ' + msg['level'] + ': ' + msg['message'], file=sys.__stdout__)
