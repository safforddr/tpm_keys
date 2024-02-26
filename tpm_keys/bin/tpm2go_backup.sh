#!/bin/sh
# Backup my local keys to a tpm2go.
# We assume that the local tpm and tpm2go have already been provisioned,
# so we are just duplicating the local DRSK to the tpm2go's DRSK.
# Read the DRSK from the tpm2go each time, in case there are multiple devices.
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

# check for 0x81000004 to make sure local tpm is provisioned
if ! tpm2_getcap handles-persistent | grep -q 0x81000004 ; then
	echo "Your system tpm does not appear to have DRSK provisioned, exiting"
	exit
fi
# check for my_drsk.pub to make sure system tpm is provisioned
if ! test -f $LOCALDIR/my_drsk.pub; then
	echo "Can't find your system's DRSK public key, exiting"
	exit
fi
# check for go_drsk.pub to make sure tpm2go is provisioned
if ! test -f $TPM2GODIR/go_drsk.pub; then
	echo "Can't find your tpm2go's DRSK public key, exiting"
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

# make sure tpm2go exists, and is started
tpm2_startup $TCTI_OPT -c 2> /dev/null || {
	echo "tpm2go not found, exiting"
	exit
}
# Read the tpm2go's DRSK from 0x81000004
tpm2_readpublic $TCTI_OPT -c 0x81000004 -o go_drsk.pub

# create dup.pub dup.dpriv and dup.seed from local DRSK
cp $LOCALDIR/my_drsk.pub dup.pub

tpm2_startauthsession --policy-session -S session.dat 
tpm2_policycommandcode -S session.dat -L dpolicy.dat TPM2_CC_Duplicate 
tpm2_policysecret -S session.dat -c o -L dpolicy.dat "$SOPW"
tpm2_loadexternal -C o -u go_drsk.pub -c go_drsk.ctx
tpm2_duplicate -C go_drsk.ctx -c 0x81000004 -G null -p "session:session.dat" -r dup.dpriv -s dup.seed 
tpm2_flushcontext session.dat 
rm session.dat

# We won't actually load the duplicate on the tpm2go.
# (We will do that as needed for recovery.)

# clean up
rm go_drsk.ctx dpolicy.dat
