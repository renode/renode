import subprocess
import fnmatch
import os

try:
    import netifaces

    def network_interface_should_exist(name):
        if name not in netifaces.interfaces():
            raise Exception('Network interface {} not found.'.format(name))

    def network_interface_should_be_up(name):
        proc = subprocess.Popen(['ip', 'addr', 'show', name, 'up'], stdout=subprocess.PIPE)
        (output, err) = proc.communicate()
        exit_code = proc.wait()
        if exit_code != 0 or len(output) == 0:
            raise Exception('Network interface {} is not up.'.format(name))

    def network_interface_should_have_address(name, address):
        network_interface_should_exist(name)
        network_interface_should_be_up(name)
        ifaddresses = netifaces.ifaddresses(name)
        addresses = []
        if netifaces.AF_INET in ifaddresses:
            addresses = [a['addr'] for a in ifaddresses[netifaces.AF_INET]]
        if address not in addresses:
            raise Exception('Network interface {0} does not have address {1}.'.format(name, address))
except:
    # netifaces is not required on Windows
    pass

def list_files_in_directory_recursively(directory_name, pattern, excludes=None):
    files = []
    for root, dirnames, filenames in os.walk(directory_name, topdown=True):
        if excludes and os.path.basename(root) in excludes:
            # this is an `os.walk` trick: when using `topdown=True`
            # you can modify `dirnames` in place to tell `os.walk`
            # which folders to visit; in this case - visit nothing
            dirnames[:] = []
            continue

        for filename in fnmatch.filter(filenames, pattern):
            files.append(os.path.join(root, filename))
    return files
