# !/usr/bin/env ruby
# Author: Mattes (https://github.com/mattes)
# Modified by: Chiedo (https://github.com/chiedojohn)
#
# Description:
# Running this script on your host machine will update boot2docker to use NFS
# instead of instead of vboxsf. Download this file and then follow the usage
# instructions below.
#
# Usage:
# boot2docker up
# ruby enable_nfs.rb

require 'erb'

bootlocalsh = %Q(#/bin/bash
sudo umount /Users
sudo /usr/local/etc/init.d/nfs-client start
sudo mount -t nfs -o noacl,async <%= vboxnet_ip %>:/Users /Users
)

machine_name = "boot2docker-vm"
 
print "Get vboxnet ip address ..."
 
# get host only adapter
vboxnet_name = `VBoxManage showvminfo #{machine_name} --machinereadable | grep hostonlyadapter`
vboxnet_name = vboxnet_name.scan(/"(.*)"/).flatten.first.chomp
if vboxnet_name == '' 
  puts "error: unable to find name of vboxnet"
  exit 1
end
 
# get ip addr for vboxnet
vboxnet_ip = ''
vboxnets = `VBoxManage list hostonlyifs`.split("\n\n")
vboxnets.each do |vboxnet|
  if vboxnet.scan(/Name: *(.+?)\n/).flatten.first.chomp == vboxnet_name
    vboxnet_ip = vboxnet.scan(/IPAddress: *(.*)\n/).flatten.first.chomp
    break
  end
end
if vboxnet_ip == ''
  puts "error: unable to find ip of vboxnet #{vboxnet_name}"
  exit 1
end

print " #{vboxnet_ip}\n"

# create record in local /etc/exports and restart nsfd
machine_ip = `boot2docker ip`.chomp
puts "Update /etc/exports ..."
`echo '\n/Users #{machine_ip} -alldirs -maproot=root\n' | sudo tee -a /etc/exports`
`awk '!a[$0]++' /etc/exports | sudo tee /etc/exports` # removes duplicate lines
`sudo nfsd restart`; sleep 2
puts `sudo nfsd checkexports`

# render bootlocal.sh and copy bootlocal.sh over to boot2docker
# (this will override an existing /var/lib/boot2docker/bootlocal.sh)
puts "Update boot2docker virtual machine ..."
bootlocalsh_rendered = ERB.new(bootlocalsh).result()
first = true
bootlocalsh_rendered.split("\n").each do |l|
  `boot2docker ssh 'echo "#{l}" | sudo tee #{first ? '' : '-a'} /var/lib/boot2docker/bootlocal.sh'`
  first = false
end
`boot2docker ssh 'sudo chmod +x /var/lib/boot2docker/bootlocal.sh'`

puts "Restart ..."
`boot2docker restart`

puts "Done."

puts
puts "Run `boot2docker ssh df` to check if NFS is mounted."
puts "Output should include something like this: '#{vboxnet_ip}:/Users [...] /Users'"
