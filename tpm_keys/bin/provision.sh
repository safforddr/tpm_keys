#!/bin/sh
# Provision keys on the local TPM, and save everything needed in MY_KEYS.
# Run this once to initialize each system, client and/or server.
#
# Note that 0x81000001 and 0x81000002 are probably Windows SRK and EK, so leave them alone
# 0x81000003 this TPM's new SRK
# 0x81000004 this TPM's new Default Recoverable Storage Key (DRSK)

# Keep the TPM_KEYS directory in the same place on all systems
# This should probably be /boot/TPM_KEYS, so it is available 
# prior to decryption of the root partition. 
BASEDIR=/boot/tpm_keys

mkdir $BASEDIR/my_keys
mkdir $BASEDIR/clients
mkdir $BASEDIR/servers
cd $BASEDIR/my_keys

# Get existing TPM owner password, or set new one
if tpm2_getcap properties-variable| grep ownerAuthSet|grep -q 1 ; then
        IFS= read -r -s -p 'Enter existing TPM owner password: ' OPW
        echo
else
        IFS= read -r -s -p 'Your TPM has no owner password. Enter a new one: ' OPW
        tpm2_changeauth -c owner "$OPW"
        echo
fi

# clean up any leftover keys
tpm2_evictcontrol -C o -c 0x81000003 -P "$OPW"
tpm2_evictcontrol -C o -c 0x81000004 -P "$OPW"

# create SRK at 0x81000003
echo "SRK" | tpm2_createprimary -c primary.ctx -P "$OPW" -u -
tpm2_evictcontrol -C o -c primary.ctx 0x81000003 -P "$OPW"

# Create default recoverable storage key (DRSK) persistent at 0x81000004.
# Use a policy that allows duplication
tpm2_startauthsession -S session.dat
tpm2_policycommandcode -S session.dat -L dpolicy.dat TPM2_CC_Duplicate
tpm2_flushcontext session.dat
rm session.dat
tpm2_create -C 0x81000003 -r my_drsk.prv -u my_drsk.pub -L dpolicy.dat -a \
	"sensitivedataorigin|userwithauth|restricted|decrypt"

# make it persistent
tpm2_load -C 0x81000003 -u my_drsk.pub -r my_drsk.prv -c my_drsk.ctx
tpm2_evictcontrol -C o -c my_drsk.ctx 0x81000004 -P "$OPW"

# hash the public key to form MYID for this host
openssl dgst -sha256 my_drsk.pub | awk '{print $2}' > myid


