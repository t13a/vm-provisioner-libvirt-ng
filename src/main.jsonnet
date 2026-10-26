// Entry point of `make gen`, evaluated with `-J lib`.
// `make gen` writes registry.libsonnet, which collects every file under the directories of src/.
// Each VM is named after its file in vms/.
local registry = import 'registry.libsonnet';

(import 'renderer.libsonnet')(std.mapWithKey(function(name, vm) vm + { name: name }, registry.vms))
