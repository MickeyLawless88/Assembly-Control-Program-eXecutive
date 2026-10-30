#!/usr/bin/env python3
"""Expand @HEADER@ @KERNEL@ @VECTORS@ in NAME.src -> ../NAME.ASM (LF endings)."""
import sys, os
d = os.path.dirname(os.path.abspath(__file__))
for name in sys.argv[1:]:
    s = open(os.path.join(d, name + '.src')).read()
    for k, f in (('@HEADER@', 'header.inc'), ('@KERNEL@', 'kernel.inc'), ('@MINI@', 'mini.inc'), ('@VECTORS@', 'vectors.inc')):
        s = s.replace(k + '\n', open(os.path.join(d, f)).read().lstrip('\n') if True else '')
    open(os.path.join(d, '..', name + '.ASM'), 'w').write(s)
