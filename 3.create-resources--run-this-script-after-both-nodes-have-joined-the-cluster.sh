# This is a script to create 2-node Active\Passive HA cluster and deploy DRBD on it.
#!/bin/bash
#
#
if [ "$(whoami)" != "root" ]
then
    sudo su -s "$0"
    exit
fi



timeout=5


echo ""
echo "######################################################################################"
echo "Configuring resources"
#Configuring resources


#pcs property set cluster-recheck-interval=2min
pcs resource defaults resource-stickiness=100
#pcs resource defaults migration-threshold=10
#pcs property set start-failure-is-fatal=true

pcs resource create win2k19server ocf:heartbeat:VirtualDomain hypervisor="qemu:///system" migration_transport="ssh" config="/etc/libvirt/qemu/win2k19.xml" meta allow-migrate="true" op stop timeout="120" interval="0" op start timeout="120" interval="0" op monitor interval="20" timeout="20"

pcs resource create ubuntu18.04server ocf:heartbeat:VirtualDomain hypervisor="qemu:///system" migration_transport="ssh" config="/etc/libvirt/qemu/ubuntu18.04.xml" meta allow-migrate="true" op stop timeout="121" interval="0" op start timeout="121" interval="0" op monitor interval="21" timeout="21"

pcs resource create ubuntu20.04server ocf:heartbeat:VirtualDomain hypervisor="qemu:///system" migration_transport="ssh" config="/etc/libvirt/qemu/ubuntu20.04server.xml" meta allow-migrate="true" op stop timeout="122" interval="0" op start timeout="122" interval="0" op monitor interval="22" timeout="22"

pcs resource create ubuntudc ocf:heartbeat:VirtualDomain hypervisor="qemu:///system" migration_transport="ssh" config="/etc/libvirt/qemu/ubuntudc.xml" meta allow-migrate="true" op stop timeout="123" interval="0" op start timeout="123" interval="0" op monitor interval="23" timeout="23"

echo "Add the DRBD resource to our previously configured Pacemaker/Corosync cluster"

pcs cluster cib add_drbd
pcs -f add_drbd resource create win2k19server_data ocf:linbit:drbd drbd_resource=r0 op monitor interval=60s

pcs -f add_drbd resource promotable win2k19server_data promoted-max=1 promoted-node-max=1 clone-max=3 clone-node-max=3 notify=true

pcs -f add_drbd resource create ubuntu18.04server_data ocf:linbit:drbd drbd_resource=r00 op monitor interval=61s

pcs -f add_drbd resource promotable ubuntu18.04server_data promoted-max=1 promoted-node-max=1 clone-max=3 clone-node-max=3 notify=true

pcs -f add_drbd resource create ubuntu20.04server_data ocf:linbit:drbd drbd_resource=r30 op monitor interval=62s

pcs -f add_drbd resource promotable ubuntu20.04server_data promoted-max=1 promoted-node-max=1 clone-max=3 clone-node-max=3 notify=true

pcs -f add_drbd resource create ubuntudc_data ocf:linbit:drbd drbd_resource=r3 op monitor interval=63s

pcs -f add_drbd resource promotable ubuntudc_data promoted-max=1 promoted-node-max=1 clone-max=3 clone-node-max=3 notify=true

pcs cluster cib-push add_drbd

pcs status

timeout=5

pcs cluster cib add_fs
pcs -f add_fs resource create win2k19server_fs Filesystem device="/dev/drbd0" directory="/home" fstype="xfs"

pcs -f add_fs resource create ubuntu18.04server_fs Filesystem device="/dev/drbd1" directory="/mnt" fstype="xfs"

pcs -f add_fs constraint colocation add win2k19server_fs with win2k19server_data-clone INFINITY with-rsc-role=Master

pcs -f add_fs constraint colocation add ubuntu18.04server_fs with ubuntu18.04server_data-clone INFINITY with-rsc-role=Master

pcs -f add_fs constraint order promote win2k19server_data-clone then start win2k19server_fs

pcs -f add_fs constraint order promote ubuntu18.04server_data-clone then start ubuntu18.04server_fs

pcs -f add_fs constraint order win2k19server_fs then win2k19server

pcs -f add_fs constraint order ubuntu18.04server_fs then ubuntu18.04server

pcs -f add_fs resource create ubuntu20.04server_fs Filesystem device="/dev/drbd2" directory="/tempr" fstype="xfs"

pcs -f add_fs resource create ubuntudc_fs Filesystem device="/dev/drbd3" directory="/temporary" fstype="xfs"

pcs -f add_fs constraint colocation add ubuntu20.04server_fs with ubuntu20.04server_data-clone INFINITY with-rsc-role=Master

pcs -f add_fs constraint colocation add ubuntudc_fs with ubuntudc_data-clone INFINITY with-rsc-role=Master
pcs -f add_fs constraint order promote ubuntudc_data-clone then start ubuntudc_fs
pcs -f add_fs constraint order ubuntudc_fs then ubuntudc

pcs -f add_fs constraint order promote ubuntu20.04server_data-clone then start ubuntu20.04server_fs

pcs -f add_fs constraint order ubuntu20.04server_fs then ubuntu20.04server

pcs cluster cib-push add_fs


timeout=5

chmod 777 /var/lib/pacemaker/cores

setsebool daemons_enable_cluster_mode=1

exit 0
