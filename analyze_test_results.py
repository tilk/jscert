#!/usr/bin/env python
"""
A tool for analyzing and comparing test results for different JS implementations.
"""

import argparse
import signal
import subprocess
import os
import getpass
import calendar
import datetime
import sqlite3 as db
import time
import re


# Our command-line interface
argp = argparse.ArgumentParser(
    description="Analyze and compare test results.")

argp.add_argument("--dbpath",action="store",metavar="path",
    default="test_data/test_results.db",
    help="Path to the database to save results in. The default should usually be fine. Please don't mess with this unless you know what you're doing.")

argp.add_argument("--run1", action="store", metavar="id",
    help="Identifier of the reference run.")

argp.add_argument("--run2", action="store", metavar="id",
    help="Identifier of the reference run.")

argp.add_argument("--list-runs", action="store_const", dest="act", const="list-runs",
    help="List test runs in the database.")

args = argp.parse_args()

con = db.connect(args.dbpath)

def list_runs():
    for (id, implementation, timestamp) in con.execute("select id, implementation, timestamp from test_batch_runs order by id desc"):
        print(id, implementation, datetime.datetime.fromtimestamp(timestamp).strftime('%Y-%m-%d %H:%M:%S'))

class test_pair:
    def __init__(self, id, status1, status2):
        self.id = id
        self.status1 = status1
        self.status2 = status2

def compare_runs(run1, run2):
    kinds = ['agreed', 'better', 'worse', 'notrun', 'wtf']
    nums = {'agreed': [], 'wtf': [], 'better': [], 'worse': [], 'notrun': []}
    for (id, status1, status2) in con.execute("select run1.test_id, run1.status, run2.status from single_test_runs run1 left outer join single_test_runs run2 on run1.test_id=run2.test_id where run1.batch_id=? and run2.batch_id=? order by run1.id", (run1, run2)):
        if status2 is None: kind = 'notrun'
        elif status1 == status2: kind = 'agreed'
        elif status1 == 'PASS': kind = 'worse'
        elif status2 == 'PASS': kind = 'better'
        else: kind = 'wtf'
        nums[kind].append(test_pair(id, status1, status2))
    for kind in kinds:
        print kind
        for o in nums[kind]:
            print "\t%s %s" % (o.id, o.status2)
    for kind in kinds:
        print "%s %d" % (kind, len(nums[kind]))

if args.act == "list-runs":
    list_runs()
else:
    compare_runs(args.run1, args.run2)

