#!/bin/sh
# migrate a key duplicated for this TPM's DRSK (0x81000004) key.
# Basically we just make sure it loads.
# Most of the real work is done in recovery.sh, which migrates
# this key back to the client.

# inputs: dup.pub, dup.dpriv, dup.seed
# outputs: dup.priv, dup.ctx

# Keep the TPM_KEYS directory in the same place on all systems
# This should probably be /boot/TPM_KEYS, so it is available 
# prior to decryption of the root partition. 
BASEDIR=/boot/tpm_keys

# we are called with $1 set to client's MYID
if [ -z "$1" ]
    then
        echo "Client ID required"
        exit 1
fi
cd $BASEDIR/clients/$1

echo "Creating duplicate policy"
tpm2_startauthsession -S session.dat
tpm2_policycommandcode -S session.dat -L dpolicy.dat TPM2_CC_Duplicate
tpm2_flushcontext session.dat
# import the duplicate key under the server key, and test that it loads
echo "migrating the duplicated key to this TPM"
tpm2_import -C 0x81000004 -u dup.pub -i dup.dpriv -r dup.prv -s dup.seed -L dpolicy.dat
tpm2_flushcontext --transient-object
tpm2_load -C 0x81000004 -u dup.pub -r dup.prv -c dup.ctx

