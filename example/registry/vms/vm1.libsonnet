local r = import '../index.jsonnet';
local t = r.templates;

t.base
+ t.cloud(image=r.images.ubuntu(version='24.04'))
+ t.dataDisk(dev='vdb', gib=10)
+ t.staticIp(ip='192.168.122.11', dns=['192.168.122.1', '1.1.1.1'])
+ {
  node: r.nodes.hv1,
  domain+: { autostart:: true, memory+: { '#text': 4096 }, vcpu: 2 },
  userData+: { packages+: ['git'] },
}
