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

sudo hostnamectl set-hostname node02
echo ""
echo "######################################################################################"
echo "Part1-Phase 1: Installing KVM, Pacemaker Cluster and DRBD on CentOS"
###Installing KVM, Pacemaker Cluster and DRBD on CentOS

dnf install epel-release
dnf config-manager --set-enabled HighAvailability
dnf --enablerepo=HighAvailability -y install pacemaker pcs corosync

systemctl enable --now pcsd

systemctl start pcsd


yum groupinstall "Virtualization Host" -y
dnf module install virt -y
dnf install virt-install virt-viewer -y
yum install virtio-win -y
yum install virt-install -y
yum install virt-manager -y
dnf install qemu-kvm qemu-img libvirt virt-install libvirt-client -y
dnf -y install virt-top libguestfs-tools

dnf install network-scripts -y

#yum install rsnapshot -y


virt-host-validate

timeout=60


rpm --import https://www.elrepo.org/RPM-GPG-KEY-elrepo.org

rpm -Uvh  https://www.elrepo.org/elrepo-release-8.el8.elrepo.noarch.rpm

dnf install kmod-drbd90.x86_64 drbd90-utils.x86_64 -y

modprobe drbd



systemctl start libvirtd.service

systemctl enable libvirtd.service

echo ""
echo "######################################################################################"
echo "Phase 3: Installing and enabling Advanced power management tool TLP"
yum install tlp tlp-rdw -y
systemctl enable tlp
systemctl start tlp


yum install ntfs-3g -y


echo ""
echo "######################################################################################"
echo "Configuring Link aggregation"

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

sudo true > /etc/hosts

sudo echo "
127.0.0.1   localhost localhost.localdomain                                   
10.0.10.253  node01 node01.localdomain
10.0.10.254  node02 node02.localdomain
" >> /etc/hosts

echo ""
echo "######################################################################################"
echo "Part 2. Basic configuration for Cluster "
echo "Part 2.Phase1: Enabling passwordless ssh connection between the nodes"

ssh-keygen -b 2048 -t rsa -q -P ""

ssh-copy-id root@node01



echo ""
echo "######################################################################################"
echo "Phase 3: Opening ports on firewall for the nodes to communicate with eachother"

#firewall-cmd --permanent --remove-port=8989/tcp
#firewall-cmd --permanent --remove-port=7799/tcp

echo "Opening TCP ports for DRBD module"
firewall-cmd --permanent --add-service=high-availability
firewall-cmd --permanent --add-port=7788/tcp
firewall-cmd --permanent --add-port=7789/tcp
firewall-cmd --permanent --add-port=7790/tcp
firewall-cmd --permanent --add-port=7799/tcp

echo "Opening UDP-ports 5404 and 5405 for Corosync"
firewall-cmd --permanent --add-port=5404/udp
firewall-cmd --permanent --add-port=5405/udp
firewall-cmd --permanent --add-port=5406/udp
firewall-cmd --permanent --add-port=5407/udp

echo "Opening TCP-port 2224 for PCS"
firewall-cmd --permanent --add-port=2224/tcp

echo "Allowing IGMP-traffic"

firewall-cmd --permanent --direct --add-rule ipv4 filter INPUT 0 -p igmp -j ACCEPT


echo "Allowing multicast-traffic"
firewall-cmd --permanent --direct --add-rule ipv4 filter INPUT 0 -m udp -p udp -m pkttype --pkt-type multicast -j ACCEPT


firewall-cmd --reload


timeout=30

echo ""
echo "######################################################################################"
echo "Phase 4: Additional configuration"

echo "hacluster:root123" | chpasswd
#sudo passwd hacluster

sudo sed -i 's/enforcing/permissive/g' /etc/selinux/config /etc/selinux/config
#sudo sestatus

echo ""
echo "######################################################################################"
echo "Part 4. Partition management for DRBD and Cluster"

#umount -fl /dev/mapper/cl-home
#lvreduce -L 500G /dev/mapper/cl-home
#lvextend -r -l +100%FREE /dev/mapper/cl-root
#lvreduce -L 250G /dev/mapper/cl-home
#lvcreate -l +100%FREE -n drbd0 cl
#lvreduce -L 200G /dev/mapper/cl-home
#umount -fl /dev/mapper/cl-drbd0
#umount -fl /dev/mapper/cl-drbd1
#umount -fl /dev/mapper/cl-drbd2
#lvremove /dev/mapper/cl-drbd0 -y
#lvremove /dev/mapper/cl-drbd1 -y
#lvremove /dev/mapper/cl-drbd2 -y
#lvreduce -L 200G /dev/mapper/cl-drbd0
#lvcreate -l +100%FREE -n drbd10 cl

umount -fl /dev/mapper/cl-home

lvremove /dev/mapper/cl-home -y

lvcreate -L 200G -n drbd0 cl00 -y

lvcreate -L 200G -n drbd1 cl00 -y

lvcreate -L 100G -n drbd2 cl00 -y

lvcreate -L 100G -n drbd3 cl00 -y



dd if=/dev/zero of=/dev/mapper/cl00-drbd0 bs=1024k count=1024

dd if=/dev/zero of=/dev/mapper/cl00-drbd1 bs=1024k count=1024

dd if=/dev/zero of=/dev/mapper/cl00-drbd2 bs=1024k count=1024

dd if=/dev/zero of=/dev/mapper/cl00-drbd3 bs=1024k count=1024


#sudo mkdir /tempr
#sudo mkdir /temporary

echo ""
echo "######################################################################################"
echo "Part 5. Configuring DRBD for Single-primary mode"
#nano /etc/drbd.d/global_common.conf (on node01 and node02):

cat /dev/null > /etc/drbd.d/global_common.conf

sudo echo "
global {
        usage-count yes;

}

common {
        handlers {
                
                 fence-peer "/usr/lib/drbd/crm-fence-peer.sh";
                 split-brain "/usr/lib/drbd/notify-split-brain.sh root";
                # out-of-sync "/usr/lib/drbd/notify-out-of-sync.sh root";#
                # before-resync-target "/usr/lib/drbd/snapshot-resync-target-lvm.sh -p$#
                 after-resync-target /usr/lib/drbd/unsnapshot-resync-target-lvm.sh;
                # quorum-lost "/usr/lib/drbd/notify-quorum-lost.sh root";#
        }

	startup {
                
        }
	options {

        }

	disk {

        }

        net {

                protocol C;
                after-sb-0pri discard-zero-changes;
                after-sb-1pri discard-secondary;
                after-sb-2pri disconnect;
        }
}

" >> /etc/drbd.d/global_common.conf


sudo echo "

resource r0 {
    device    /dev/drbd0;
    disk      /dev/mapper/cl00-drbd0;
    meta-disk internal;
  on nordnode01 {
    address   10.0.10.253:7788;
  }
  on nordnode02 {
    address   10.0.10.254:7788;
  }
}" >> /etc/drbd.d/r0.res

sudo echo "

resource r00 {
    device    /dev/drbd1;
    disk      /dev/mapper/cl00-drbd1;
    meta-disk internal;
  on nordnode01 {
    address   10.0.10.253:7789;
  }
  on nordnode02 {
    address   10.0.10.254:7789;
  }
}" >> /etc/drbd.d/r00.res

sudo echo "

resource r30 {
    device    /dev/drbd2;
    disk      /dev/mapper/cl00-drbd2;
    meta-disk internal;
  on nordnode01 {
    address   10.0.10.253:7790;
  }
  on nordnode02 {
    address   10.0.10.254:7790;
  }
}" >> /etc/drbd.d/r30.res


sudo echo "

resource r3 {
    device    /dev/drbd3;
    disk      /dev/mapper/cl00-drbd3;
    meta-disk internal;
  on nordnode01 {
    address   10.0.10.253:7799;
  }
  on nordnode02 {
    address   10.0.10.254:7799;
  }
}" >> /etc/drbd.d/r3.res

drbdadm create-md r0

drbdadm create-md r00

drbdadm create-md r30

drbdadm create-md r3


drbdadm up r0

drbdadm up r00

drbdadm up r30

drbdadm up r3


drbdadm secondary r0

drbdadm secondary r00

drbdadm secondary r30

drbdadm secondary r3


semanage permissive -a drbd_t

chmod 777 /var/lib/pacemaker/cores



wget -q -O - http://linux.dell.com/repo/hardware/latest/bootstrap.cgi | bash

#bash bootstrap.cgi -y

yum install srvadmin-base -y
yum install srvadmin-storageservices -y
yum install srvadmin-all --allowerasing -y

export PATH=$PATH:/opt/dell/srvadmin/bin

/opt/dell/srvadmin/sbin/srvadmin-services.sh start

ln -s /opt/dell/srvadmin/bin/omreport /sbin/omreport

chmod +s /opt/dell/srvadmin/bin/omreport

#/sbin/omreport storage vdisk
#omreport storage pdisk controller=0


exit 0
