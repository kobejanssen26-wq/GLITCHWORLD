import os, json, sys
root = sys.argv[1]
def node_for_dir(path, name):
    children = []
    for f in sorted(os.listdir(path)):
        p = os.path.join(path, f)
        if os.path.isdir(p):
            children.append(node_for_dir(p, f))
        elif f.endswith('.luau'):
            if f.endswith('.server.luau'): cls, n = 'Script', f[:-12]
            elif f.endswith('.client.luau'): cls, n = 'LocalScript', f[:-12]
            else: cls, n = 'ModuleScript', f[:-5]
            children.append({'name': n, 'className': cls, 'filePaths': [os.path.relpath(p, root)]})
    return {'name': name, 'className': 'Folder', 'children': children}
shared = node_for_dir(os.path.join(root,'src/shared'),'Shared')
server = node_for_dir(os.path.join(root,'src/server'),'Server')
client = node_for_dir(os.path.join(root,'src/client'),'Client')
tree = {'name':'GlitchWorld','className':'DataModel','children':[
 {'name':'ReplicatedStorage','className':'ReplicatedStorage','children':[shared]},
 {'name':'ServerScriptService','className':'ServerScriptService','children':[server]},
 {'name':'StarterPlayer','className':'StarterPlayer','children':[{'name':'StarterPlayerScripts','className':'StarterPlayerScripts','children':[client]}]},
]}
json.dump(tree, open(os.path.join(root,'sourcemap.json'),'w'), indent=1)
