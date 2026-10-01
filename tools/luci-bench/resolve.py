import sys, re, os, urllib.request
feeds = {'base':'https://downloads.openwrt.org/releases/19.07.10/packages/x86_64/base',
         'luci':'https://downloads.openwrt.org/releases/19.07.10/packages/x86_64/luci',
         'packages':'https://downloads.openwrt.org/releases/19.07.10/packages/x86_64/packages',
         'core':'https://downloads.openwrt.org/releases/19.07.10/targets/x86/64/packages'}
pk = {}; prov = {}
for f,u in feeds.items():
    cur = None
    for line in open('Packages-'+f, errors='replace'):
        line=line.rstrip('\n')
        if line.startswith('Package: '):
            cur = {'name': line[9:], 'feed': f, 'url': u}; pk.setdefault(cur['name'], cur)
        elif cur and line.startswith('Depends: '):
            cur['deps'] = [re.split(r'[ (]', d.strip())[0] for d in line[9:].split(',')]
        elif cur and line.startswith('Provides: '):
            for p in line[10:].split(','): prov.setdefault(p.strip(), cur['name'])
        elif cur and line.startswith('Filename: '):
            cur['file'] = line[10:]
installed = set(open('installed.txt').read().split())
want = sys.argv[1:]; seen=set(); out=[]
while want:
    n = want.pop()
    n = n if n in pk else prov.get(n, n)
    if n in seen or n in installed or n in ('libc','kernel'): continue
    seen.add(n)
    if n not in pk: print('MISSING', n, file=sys.stderr); continue
    out.append(pk[n]); want += pk[n].get('deps', [])
for p in out:
    dst = 'ipk/' + os.path.basename(p['file'])
    if not os.path.exists(dst):
        urllib.request.urlretrieve(p['url']+'/'+p['file'], dst)
    print(dst)
