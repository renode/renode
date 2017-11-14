#!/usr/bin/python
from __future__ import print_function
import sys
import argparse
import xml.etree.ElementTree

def merge(files, output):
    base_xml = xml.etree.ElementTree.parse(files[0])
    base_root = base_xml.getroot()

    base_root.attrib['name'] = 'Merged results'

    ids = ['total', 'errors', 'failures', 'not-run', 'inconclusive', 'ignored', 'skipped', 'invalid']
    stats = {}

    # read statistics from base file
    for i in ids:
        stats[i] = int(base_root.attrib[i])

    for curr_root in (xml.etree.ElementTree.parse(f).getroot() for f in files[1:]):
        # update statistics
        for i in ids:
            stats[i] += int(curr_root.attrib[i])
        # copy all top level test-suite elements
        for ts in curr_root.findall('test-suite'):
            base_root.append(ts)

    # update statistics
    for i in ids:
        base_root.attrib[i] = str(stats[i])

    base_xml.write(output)

if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument("files", help="Xml files to merge", nargs='*')
    parser.add_argument("-o", "--output", dest="output", help="Output file name", default='output.xml')
    options = parser.parse_args()

    if len(options.files) < 2:
        print("You must provide at least two files to merge", file=sys.stderr)
        sys.exit(1)

    merge(options.files, options.output)

