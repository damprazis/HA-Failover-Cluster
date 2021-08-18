# HA-Failover-Cluster
2-node High Availability active-active failover cluster deployment scripts



Concepts and Architecture

The high availability cluster consists of two hosts (Two physical machines) that act as a single system and provide continuous availability.
This cluster has an active/active design, there are two physical nodes with the same configuration acting as a Hypervisor by the use of KVM where the virtual machines are created and stored. Each of these VMs can be directly accessed by clients. Each of the VMs is acting as a resource in a pacemaker cluster (More on this later on in this manual).

The highly available architecture provides redundancy using the following process:
1.	Detecting failure
2.	Performing failover of the application to another redundant host
3.	Restarting or repairing the failed server without requiring manual intervention

Breaking down of what a highly available failover cluster consists of:
Each of the VMs, as mentioned above, is acting as a resource in a pacemaker cluster. Pacemaker is a resource manager that can start and stop resources (VMs in our case)

Corosync/Heartbeat is a replication method. The purpose of this technique is to monitor cluster node health via a dedicated network connection. Each node in the cluster constantly advertises its availability to the other nodes by sending a “heartbeat” over the dedicated network link (More on this will be explained in explaining the resource creation process).

Each of the VMs (*.qcow2) image file is some sort of a “roaming profile” that will transfer itself with the help of DRBD module to the failover node of the cluster. DRBD is a file synchronization module which will keep filesystems equal at all cluster nodes.
As an active/active solution, once the resources failover from one node to the other one, the resources will remain to the second node even if the “primary” node comes back to life. This is to prevent the resources from unnecessary node hopping that will create unnecessary downtime. (More on this will be explained in describing the resource creation process).

Assumptions:
Installation of CentOS is happening on a preconfigured RAID5 configuration with total capacity of 2.7 TB.
After the CentOS 8 installation root occupies 50GB and the rest of the partition is mainly allocated to /home partition (2.1 TB approximately) and /swap.
There is going to be some re-partitioning, after the installation, to free-up some space for the later registered resources for the cluster.

Preparation for Running the scripts:
Start with configuring both cluster nodes with a static IP (that will be part of NIC Bonding first) and a proper hostname.
It’s advised to set hostname and create the Link aggregation first before running the scripts.

The hostname and NIC bonding configuration is also in the script but better to do it separately first for each node and then comment out their respective part in the scripts.
sudo hostnamectl set-hostname node02 (For secondary node)
sudo hostnamectl set-hostname node01 (For primary node)
 For creating the NIC bonding run the following as root:

sudo touch /etc/modprobe.d/nic-bonding.conf

sudo echo "
cat nic-bonding.conf
alias netdev-bond0 bonding
" >> /etc/modprobe.d/nic-bonding.conf


sudo true > /etc/sysconfig/network-scripts/ifcfg-enp1s0f3

sudo echo "
DEVICE=enp1s0f3
NAME=enp1s0f3
ONBOOT=yes
TYPE=Ethernet
BOOTPROTO=none
MASTER=bond0
SLAVE=yes
" >> /etc/sysconfig/network-scripts/ifcfg-enp1s0f3


sudo true > /etc/sysconfig/network-scripts/ifcfg-eno2

sudo echo "
DEVICE=eno2
NAME=eno2
ONBOOT=yes
TYPE=Ethernet
BOOTPROTO=none
MASTER=bond0
SLAVE=yes
" >> /etc/sysconfig/network-scripts/ifcfg-eno2


sudo touch /etc/sysconfig/network-scripts/ifcfg-bond0

sudo echo "
DEVICE=bond0
NAME=bond0
TYPE=Bond
ONBOOT=yes
BOOTPROTO=none
IPADDR=10.0.10.253
NETMASK=255.255.255.0
BONDING_MASTER=yes
BONDING_OPTS="miimon=80 mode=4 xmit_hash_policy=1 lacp_rate=1"

" >> /etc/sysconfig/network-scripts/ifcfg-bond0

And don’t forget to update hosts file by running the following:


sudo true > /etc/host

sudo echo "
127.0.0.1   localhost localhost.localdomain                                   
10.0.10.253  node01 node01.localdomain
10.0.10.254  node02 node02.localdomain
" >> /etc/hosts

After that we restart both nodes for the hostname change to take effect and now we can go ahead and run the scripts

The scripts basically install pacemaker, corosync/heartbeat, pcs and KVM.
After this first part of installation is finished, passwordless shh communication between the nodes is configured. This type of communication will be used by corosync/heartbeat to monitor cluster node health.
Moreover, the script continues by opening firewall ports of the above mentioned software.
 
From now on the script continues on creating a user hacluster:root123 that will be used only once to authenticate the nodes later on in the cluster.

The next part of the script, will go ahead and repartition the remaining free space after deleting /home directory which is not needed and will remounted as part of the DRBD module later on during the creating resources process.
The following repartitioning will be used by DRBD module to store the KVM images of the virtual machines.

Changing the config file of DRBD to register these new partitions as well as creating these new roaming disks.
Some essential changes to the QEMU/KVM config file is next on the script to provide root privileges to all disks created for DRBD. That is because during Cluster failover testing when you physically remove one HDD, some of the resources were failing to failover because of that root privilege configuration missing on the config file.

That was the process for preparing node02 (Secondary node). Preparing the primary node next (node01) will the next necessary step as the initiation of the cluster as well as the authentication of the nodes will be done there.

90% of this script is the same as the script for node02 that was deployed first. The only difference is that after creating the DRBD shared drives, we will need to wait for the drive to synchronize themselves.
This will take some time.
After the synchronization, we need to format these newely created drives with below command.

sudo mkfs.xfs /dev/drbd0 && sudo mkfs.xfs /dev/drbd1 && sudo mkfs.xfs /dev/drbd2 && sudo mkfs.xfs /dev/drbd3

The script will probably not do that because the synchronization needs to finish first.
If you want you can comment this part out of the script and do it manually later on.
Below is the part of the script for node01 that sets up, initiates and authenticates the nodes for the cluster
 
During the “pcs host auth node01 node02” command execution you will be asked to enter username and password with which both nodes will be authenticated in the cluster.

As mentioned earlier in this manual. you will need to use hacluster:root123.

enp1s0f3 and eno2 network profiles are used to form a link aggregation. The bonding IP for node01 is 10.0.10.253 and for node02 is 10.0.10.254.

 

