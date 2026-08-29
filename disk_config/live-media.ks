lang en_US.UTF-8
keyboard us
timezone UTC --utc
rootpw --lock
shutdown
bootloader --append="selinux=0"

part / --fstype=ext4 --size=28672

%packages
dracut-live
%end
