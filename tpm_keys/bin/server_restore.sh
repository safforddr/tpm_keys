#!/bin/sh
# Migrate a key back to the client
# input from client - srk2.pub
# Duplicates "dup.*" to "recover.*" under the new srk2.pub

# Keep the TPM_KEYS directory in the same place on all systems
# This should probably be /boot/tpm_keys, so it is available 
# prior to decryption of the root partition. 
BASEDIR=/boot/tpm_keys

# we are called with $1 set to client's MYID
if [ -z "$1" ]
    then
        echo "Client ID required"
        exit 1
fi
cd $BASEDIR/clients/$1

tpm2_startauthsession --policy-session -S session.dat 
tpm2_policycommandcode -S session.dat -L policy.dat TPM2_CC_Duplicate 
# load client's SRK2 public key
tpm2_loadexternal -C o -u srk2.pub -c srk2.ctx
tpm2_duplicate -C srk2.ctx -c dup.ctx -G null -p "session:session.dat" -r recover.dpriv -s recover.seed 
cp dup.pub recover.pub
tpm2_flushcontext session.dat 
