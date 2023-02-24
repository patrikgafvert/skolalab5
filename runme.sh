#!/usr/bin/env bash
# Make some global vars
vms=()
files=()
gitea_servers_count="$TF_VAR_gitea_servers_count"

ansfilename="main_ans.yml"
anshostfile="hosts_ans.yml"
cifilename="bastioncloudinit.ci"
files+=("${ansfilename}" "${anshostfile}")
sshkeyext="_id_rsa"
vms=("bastion")

# Make the names for the gitea servers.
for ((i=0;i<${gitea_servers_count};i++))
do
	vms+=("gitea_server_$((${i}+1))")
done

# Generate the pri/pub ssh keys for all vms
for vmsname in "${vms[@]}"
do
	rm "${vmsname}${sshkeyext}" "${vmsname}${sshkeyext}.pub"
	ssh-keygen -t rsa -N "" -C "${vmsname}" -f "${vmsname}${sshkeyext}"
	files+=("${vmsname}${sshkeyext}")
done

# Remove the old file
rm $anshostfile

# Lets make a new one.
echo "all:" >> $anshostfile
echo "  hosts:" >> $anshostfile
for ((i=0;i<${gitea_servers_count};i++))
do
	echo "    10.0.1.2${i}:" >> $anshostfile
	echo "      ansible_ssh_private_key_file: \"gitea_server_$((${i}+1))_id_rsa\"" >> $anshostfile
	echo "      ansible_ssh_common_args: \"-o StrictHostKeyChecking=no\"" >> $anshostfile
done

# Remove the old cloudinit file
rm $cifilename

# Lets make a new cloudinit file
echo "#cloud-config" >> $cifilename
echo "package_update: true" >> $cifilename
echo "packages:" >> $cifilename
echo "  - \"ansible\"" >> $cifilename
echo "write_files:" >> $cifilename

for filename in "${files[@]}"
do
	echo "  - path: \"/home/ubuntu/${filename}\"" >> $cifilename
	echo "    encoding: \"base64\"" >> $cifilename
	echo "    owner: \"ubuntu:ubuntu\"" >> $cifilename
	echo "    permissions: \"0600\"" >> $cifilename
	echo "    defer: true" >> $cifilename
	echo "    content: |" >> $cifilename
	for line in $(base64 $filename)
	do 
		echo "      ${line}" >> $cifilename
	done
done
echo "runcmd:" >> $cifilename
echo "  - sudo su - ubuntu -c \"ansible-playbook -i ${anshostfile} ${ansfilename}\"" >> $cifilename

terraform init
terraform apply -auto-approve