#!/bin/sh
# Restore my DRSK from a tpm2go.
# The tpm2go's DRSK public key should be go_drsk.pub
# The backups should be dup.pub dup.dpriv and dup.seed from local DRSK
# We need to load them on the tpm2go, and duplicate them for the new local SRK,
# then load and make them persistent.
#
# Note that 0x81000001 and 0x81000002 are probably Windows SRK and EK, so leave them alone
# 0x81000003 this TPM's new SRK
# 0x81000004 this TPM's new Default Recoverable Storage Key (DRSK)
#
# We assume the local DRSK keys are already in BASEDIR/my_keys
# We don't assume the tpm2go is using abrmd, so flush as needed...

BASEDIR=/boot/tpm_keys
LOCALDIR=$BASEDIR/my_keys
TPM2GODIR=$BASEDIR/tpm2go
TCTI_OPT="-T spi-ltt2go"

mkdir -p $TPM2GODIR
cd $TPM2GODIR

# check for prerequisites
if ! test -f go_drsk.pub; then
	echo "Can't fine tpm2go's DRSK, exiting"
	exit
fi
# check for dup.pub
if ! test -f dup.pub; then
	echo "Can't find backup file, exiting"
	exit
fi
# check for dup.dpriv
if ! test -f dup.dpriv; then
	echo "Can't find backup file, exiting"
	exit
fi
# check for dup.seed
if ! test -f dup.seed; then
	echo "Can't find backup file, exiting"
	exit
fi

# make sure tpm2go exists, and is started
tpm2_startup $TCTI_OPT -c 2> /dev/null || {
	echo "tpm2go not found, exiting"
	exit
}

# Read the tpm2go's DRSK from 0x81000004 and check that it is the right device
tpm2_readpublic $TCTI_OPT -Q -c 0x81000004 -o go_restore_drsk.pub
if ! cmp -s go_drsk.pub go_restore_drsk.pub; then
	echo "This does not seem to be the correct tpm2go, exiting."
	exit
fi

# Get existing TPM owner password, or exit
if tpm2_getcap properties-variable| grep ownerAuthSet|grep -q 1 ; then
        IFS= read -r -s -p 'Enter existing System TPM owner password: ' SOPW
        echo
else
	echo "Your System TPM does not appear to be provisioned. Exiting."
	exit
fi

# Get existing tpm2go owner password
if tpm2_getcap $TCTI_OPT properties-variable | grep ownerAuthSet|grep -q 1 ; then
        IFS= read -r -s -p 'Enter existing tpm2go TPM owner password: ' GOPW
        echo
else
	echo "Your tpm2go is not provisioned, exiting"
	exit
fi
tpm2_flushcontext $TCTI_OPT -t
sleep 1

# Normally we run recovery only if we have a new TPM.
# For demo purposes, evict the local tpm's existing SRK and DRSK 
tpm2_evictcontrol -C o -c 0x81000003 -P "$SOPW"
tpm2_evictcontrol -C o -c 0x81000004 -P "$SOPW"

# create new SRK2 - We use "SRK2" to make a different SRK for demo purposes
echo "SRK2" | tpm2_createprimary -c primary.ctx -P "$SOPW" -u - 
tpm2_evictcontrol -C o -c primary.ctx 0x81000003 -P "$SOPW"

echo "reading system tpm's srk"
tpm2_readpublic -c 0x81000003 -o srk2.pub
tpm2_flushcontext $TCTI_OPT -t

# first have to import and load dup key
echo "Creating duplicate policy"
tpm2_startauthsession $TCTI_OPT -S session.dat
tpm2_policycommandcode $TCTI_OPT -S session.dat -L dpolicy.dat TPM2_CC_Duplicate
tpm2_policysecret $TCTI_OPT -S session.dat -c o -L dpolicy.dat $SOPW
tpm2_flushcontext $TCTI_OPT session.dat
tpm2_flushcontext $TCTI_OPT -t
sleep 1

# import the duplicate key under the tpm2go DRSK
echo "Importing the dup key to the tpm2go"
tpm2_import $TCTI_OPT -C 0x81000004 -u dup.pub -i dup.dpriv -r dup.prv -s dup.seed -L dpolicy.dat
tpm2_flushcontext $TCTI_OPT -t

# load duplicated DRSK on tpm2go
echo "loading dup keys on tpm2go"
tpm2_load $TCTI_OPT -C 0x81000004 -u dup.pub -r dup.prv -c dup.ctx
tpm2_flushcontext $TCTI_OPT -t

echo "setup keys for duplication"
tpm2_startauthsession $TCTI_OPT --policy-session -S session.dat 
tpm2_policycommandcode $TCTI_OPT -S session.dat -L dpolicy.dat TPM2_CC_Duplicate 
tpm2_policysecret $TCTI_OPT -S session.dat -c o -L dpolicy.dat $SOPW

# load client's SRK2 public key
echo "loading srk2"
tpm2_loadexternal $TCTI_OPT -C o -u srk2.pub -c srk2.ctx
tpm2_flushcontext $TCTI_OPT -t

# Duplicate it under the new local TPM SRK to recover.pub and recover.dpriv
echo "duplicating for srk2"
tpm2_duplicate $TCTI_OPT -C srk2.ctx -c dup.ctx -G null -p "session:session.dat" -r recover.dpriv -s recover.seed 
cp dup.pub recover.pub
tpm2_flushcontext $TCTI_OPT session.dat 
tpm2_flushcontext $TCTI_OPT -t

# Load the duplicated DRSK under new local TPM SRK
tpm2_startauthsession -S session.dat
tpm2_policycommandcode -S session.dat -L dpolicy.dat TPM2_CC_Duplicate
tpm2_policysecret -S session.dat -c o -L dpolicy.dat "$SOPW"
tpm2_flushcontext session.dat
tpm2_import -C 0x81000003 -u recover.pub -i recover.dpriv -r recover.prv -s recover.seed -L dpolicy.dat
tpm2_flushcontext --transient-object
tpm2_load -C 0x81000003 -u recover.pub -r recover.prv -c recover.ctx

# Make it persistent
tpm2_evictcontrol -C o -c recover.ctx 0x81000004 -P "$SOPW"

# cleanup
cp recover.prv $LOCALDIR/my_drsk.prv
cp recover.pub $LOCALDIR/my_drsk.pub
rm -f recover.* srk2.* *.dat *.ctx

