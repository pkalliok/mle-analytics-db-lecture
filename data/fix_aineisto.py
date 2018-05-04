#!/usr/bin/env python3

from csv import writer
from datetime import datetime
import sys, re
#from json import dumps

ends_with_referrer_re = re.compile(r'^(.*),"([^,]*)"$')
split_first_fields_re = re.compile(r'^([0-9:.]*),"([^"]*)",(.*)$')
split_away_timezone_re = re.compile(r'^(.*)[+-][0-9]{4}$')

def find_fields(lines):
    for line in lines:
        line_structure = split_first_fields_re.match(line)
        if not line_structure: continue
        peer, time, rest = line_structure.groups()
        rest_structure = ends_with_referrer_re.match(rest)
        if not rest_structure: yield (peer, time, rest, None)
        else:
            address, referrer = rest_structure.groups()
            yield (peer, time, address, referrer)

def fix_date(datestring):
    (date,) = split_away_timezone_re.match(datestring).groups()
    return datetime.strptime(date, "%d/%b/%Y:%H:%M:%S").isoformat()

def fix_fields(rows):
    return ((peer, fix_date(time), address, referrer)
            for peer, time, address, referrer in rows)

def write_data(rows):
    w = writer(sys.stdout)
    for row in rows: w.writerow(row)

if __name__ == '__main__':
    write_data(fix_fields(find_fields(open(sys.argv[1]))))
