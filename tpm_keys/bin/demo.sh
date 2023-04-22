#!/bin/bash
# demo.sh <recovery server name or IP address>

# Keep the TPM_KEYS directory in the same place on all systems
# This should probably be /boot/tpm_keys, so it is available 
# prior to decryption of the root partition. 
BASEDIR=/boot/tpm_keys

# this argument can be a DNS name or IP address...
if [ -z "$1" ]
    then
        echo "Server name or address required"
        exit 1
fi
SERVERADDR=$1

# Get existing TPM owner password, or set new one
if tpm2_getcap properties-variable| grep ownerAuthSet|grep -q 1 ; then
        IFS= read -r -s -p 'Enter existing TPM owner password: ' OPW
        echo
else
        IFS= read -r -s -p 'Your TPM has no owner password. Enter a new one: ' OPW
        tpm2_changeauth -c owner "$OPW"
        echo
fi

#create trusted key under current recoverable DRSK at 0x81000004
keyctl add trusted kmk "new 32 keyhandle=0x81000004 migratable=1" @u 
keyctl pipe `keyctl show @u|grep kmk|awk '{print $1}'` > kmk.blob 

# kill current SRK and DRSK
tpm2_evictcontrol -C o -c 0x81000003 -P "$OPW"
tpm2_evictcontrol -C o -c 0x81000004 -P "$OPW"
keyctl clear @u

# recover.sh will create a new SRK2 and recover existing DRSK
$BASEDIR/bin/restore.sh $SERVERADDR

# test kmk blob still works
keyctl add trusted kmk2 "load `cat kmk.blob`" @u 
keyctl show @u

