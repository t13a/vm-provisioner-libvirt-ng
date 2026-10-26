function(version) {
  url: 'https://cloud-images.ubuntu.com/releases/' + version + '/release/ubuntu-' + version + '-server-cloudimg-amd64.img',
  volume: 'ubuntu-cloud-' + version + '-amd64.qcow2',
  format: 'qcow2',
  sshUser: 'ubuntu',
}
