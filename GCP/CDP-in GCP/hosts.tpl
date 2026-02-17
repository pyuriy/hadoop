[all_nodes]
%{ for node in nodes ~}
${node.name} ansible_host=${node.network_interface[0].access_config[0].nat_ip}
%{ endfor ~}

[cm_server]
${nodes[0].name} ansible_host=${nodes[0].network_interface[0].access_config[0].nat_ip}

[all_nodes:vars]
ansible_user=${ssh_user}
ansible_ssh_private_key_file=~/.ssh/id_rsa
