#!/usr/bin/env python3

import argparse
import sqlite3 as db
import cgi

# Our command-line interface
argp = argparse.ArgumentParser(
    description="Analyze and compare test results.")

argp.add_argument("--dbpath",action="store",metavar="path",
    default="test_data/test_results.db",
    help="Path to the database to save results in. The default should usually be fine. Please don't mess with this unless you know what you're doing.")

argp.add_argument("--run", action="store", metavar="id", type=int,
    help="Identifier of the reference run.")

args = argp.parse_args()

con = db.connect(args.dbpath)

class node:
    def __init__(self):
        self.children = {}
        self.tests = []
        self.stats = {}
    def add_stat(self, stat, cnt=1):
        if stat not in self.stats:
            self.stats[stat] = 0
        self.stats[stat] += cnt
    def add_stats(self, stats):
        for (stat, cnt) in stats.items():
            self.add_stat(stat, cnt)
    def get_stats(self):
        ret = []
        for (stat, cnt) in self.stats.items():
            ret.append("%s: %d" % (stat, cnt))
        return ", ".join(ret)
    def get_stat(self, stat):
        if stat in self.stats: return self.stats[stat]
        else: return 0
    def get_stat_bar(self):
        npass = self.get_stat("PASS")
        nabrt = self.get_stat("ABORT")
        nfail = self.get_stat("FAIL")
        total = npass + nabrt + nfail
        if total == 0: return ""
        wpass = 100.0*npass/total
        wabrt = 100.0*nabrt/total
        wfail = 100.0*nfail/total
        return """<div class="resbar"><div style="width: %.2f%%" title="%d" class="resbar-pass">%d</div><div style="width: %.2f%%" title="%d" class="resbar-abrt">%d</div><div style="width: %.2f%%" title="%d" class="resbar-fail">%d</div></div>""" % (wpass, npass, npass, wabrt, nabrt, nabrt, wfail, nfail, nfail)

class test:
    def __init__(self, fullname, id, stat, out, err):
        self.fullname = fullname
        self.id = id
        self.stat = stat
        self.out = out
        self.err = err

testtree = node()

for (id, stat, out, err) in con.execute("select test_id, status, stdout, stderr from single_test_runs where batch_id=? order by test_id", (args.run,)):
    p = id.split("/")
    root = testtree
    for i in p[:-1]:
        if i not in root.children:
            root.children[i] = node()
        root = root.children[i]
    root.tests.append(test(id, p[-1], stat, out, err))

def update_stats(n):
    for t in n.tests:
        n.add_stat(t.stat)
    for nn in n.children.values():
        update_stats(nn)
        n.add_stats(nn.stats)

update_stats(testtree)

out = open("nice_reports/report_%d.html" % args.run, "w")

out.write("""<!DOCTYPE html>
<html>
<head>
<title></title>
<link rel="stylesheet" href="dist/themes/default/style.css" />
<link rel="stylesheet" href="rainbow/themes/github.css" />
<script src="dist/libs/jquery.js"></script>
<script src="dist/jstree.min.js"></script>
<script src="rainbow/rainbow.js"></script>
<script src="rainbow/language/generic.js"></script>
<script src="rainbow/language/javascript.js"></script>
<style type="text/css">
.resbar {
    width: 150px;
    height: 15px;
    display: block;
    position: absolute;
    right: 10px; top: 0px;
}

.resbar > div {
    height: 15px;
    display: inline-block;
    font-size: 9px;
    vertical-align: middle;
    overflow: hidden;
    color: white;
}

.resbar > .resbar-pass {
    background: green;
}

.resbar > .resbar-abrt {
    background: yellow;
    color: black;
}

.resbar > .resbar-fail {
    background: red;
}

li {
    position: relative;
}

#tree {
    position: fixed;
    width: 33%; height: 100%;
    left: 0px; top: 0px;
    overflow: scroll;
}

#tree .jstree-PASSicon {
    background-position: -3px -68px !important;
}
#tree .jstree-ABORTicon {
    background-position: -35px -68px !important;
}
#tree .jstree-FAILicon {
    background-position: -35px -68px !important;
}

#right {
    position: absolute;
    left: 35%; top: 0px; width: 64%;
}
#tree .outdata, #tree .errdata { display: none; }
</style>
</head>
<body>
<div id="right">
</div>
<div id="tree">""")

def format_output(s):
    return cgi.escape(s).replace("\n", "<br>")

def write_node(n):
    if len(n.children) == 0 and len(n.tests) == 0: return
    out.write("""<ul>""")
    for t in n.tests:
        out.write("""<li class="testitem" fullname="%s" data-jstree='{"icon":"jstree-icon jstree-%sicon"}'>%s: %s<div class="outdata">%s</div><div class="errdata">%s</div></li>""" % (t.fullname, t.stat, t.id, t.stat, format_output(t.out), format_output(t.err)))
    for (i,nn) in sorted(n.children.items()):
        out.write("""<li>%s %s""" % (i, nn.get_stat_bar()))
        write_node(nn)
        out.write("""</li>""")
    out.write("""</ul>""")

write_node(testtree)

out.write("""</div>
<script>$(function () { 
  $('#tree').jstree(); 
  $('#tree').on("click", "li.testitem", function() {
    $('#right').empty();
    $('#right').append("<h2>stdout</h2>");
    $(this).find(".outdata").clone().appendTo('#right');
    $('#right').append("<h2>stderr</h2>");
    $(this).find(".errdata").clone().appendTo('#right');
    $('#right').append("<h2>source</h2><pre><code id='testsrc' data-language='javascript'></code></pre>");
    $.get($(this).attr("fullname"), function(data) {
        $('#testsrc').text(data);
        Rainbow.color($('#testsrc'));
    }, "text");
  });
});</script>
</body>
</html>""")

out.close()

