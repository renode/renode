class term_color:
    BLUE = '\033[94m'
    YELLOW = '\033[93m'
    RED = '\033[91m'
    RESET = '\033[0m'


ROBOT_LISTENER_API_VERSION = 3


def start_test(data, result):
    print('+++++ ' + data.longname)


def end_test(data, result):
    if not result.passed:
        if 'skipped' in result.tags:
            print(term_color.BLUE + 'skipped' + term_color.RESET + ': %s' % data.longname)
        elif 'non_critical' in result.tags:
            print(term_color.YELLOW + 'failed (non critical)' + term_color.RESET + ': %s' % data.longname)
        else:
            print(term_color.RED + 'failed' + term_color.RESET + ': %s' % data.longname)
        print('\t%s' % result.message)
