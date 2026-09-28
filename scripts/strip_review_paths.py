"""Turn a Codex review's absolute local links ([text](/Users/<name>/.../repo/FILE:LINE)) into plain `FILE:LINE` text
and replace any other home path, so review records carry no home paths and no dead links. usage: python3 scripts/strip_review_paths.py FILE..."""
import re, sys

for path in sys.argv[1:]:
    s = open(path).read()
    s = re.sub(r"\[([^\]]*)\]\(/Users/[^/]+/4090/([^)]+)\)", lambda m: f"`{m.group(2)}`", s)
    s = re.sub(r"/Users/[^/\s]+/4090/", "", s)
    s = re.sub(r"(/Users|/home)/[A-Za-z0-9._-]+", "a personal home path", s)
    open(path, "w").write(s)
