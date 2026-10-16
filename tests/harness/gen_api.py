#!/usr/bin/env python3
"""Generate a Luau table of Roblox class members (properties / methods / events) from luau-lsp's globalTypes.d.luau.
Used by the mock-Roblox smoke tests to reject unknown property names, which static typing cannot see through
UIKit.new(class, {props}) style helpers.   usage: gen_api.py globalTypes.d.luau out.luau"""
import re, sys
src = open(sys.argv[1], encoding='utf-8').read().split('\n')
classes = {}
cur = None
for line in src:
    m = re.match(r'^declare extern type (\w+)(?: extends (\w+))? with\s*$', line)
    if m:
        cur = {'extends': m.group(2), 'props': {}, 'methods': set(), 'events': set()}
        classes[m.group(1)] = cur
        continue
    if cur is None:
        continue
    if line.startswith('end'):
        cur = None
        continue
    mp = re.match(r'^\t([A-Za-z_]\w*): (.+?)\s*$', line)
    if mp:
        name, typ = mp.group(1), mp.group(2)
        if typ.startswith('RBXScriptSignal'):
            cur['events'].add(name)
        else:
            cur['props'][name] = typ
        continue
    mf = re.match(r'^\t+function (\w+)\(self', line)
    if mf:
        cur['methods'].add(mf.group(1))
out = ['return {']
for name, c in sorted(classes.items()):
    props = ','.join('%s="%s"' % (k, v.replace('"', "'")) for k, v in sorted(c['props'].items()))
    meth = ','.join('%s=true' % k for k in sorted(c['methods']))
    ev = ','.join('%s=true' % k for k in sorted(c['events']))
    out.append('%s={extends=%s,props={%s},methods={%s},events={%s}},' % (name, '"%s"' % c['extends'] if c['extends'] else 'nil', props, meth, ev))
out.append('}')
open(sys.argv[2], 'w', encoding='utf-8').write('\n'.join(out))
print('classes:', len(classes))
