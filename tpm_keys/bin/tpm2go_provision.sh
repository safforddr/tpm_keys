#!/bin/sh
# provision a tpm2go device with an SRK and DRSK.
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

# make sure it has been started
tpm2_startup $TCTI_OPT -c 2> /dev/null || {
	echo "tpm2go not found, exiting"
	exit
}

# Get existing tpm2go TPM owner password, or set new one
if tpm2_getcap $TCTI_OPT properties-variable | grep ownerAuthSet|grep -q 1 ; then
        IFS= read -r -s -p 'Enter existing tpm2go TPM owner password: ' GOPW
        echo
else
        IFS= read -r -s -p 'Your tpm2go TPM has no owner password. Enter a new one: ' GOPW
        tpm2_changeauth $TCTI_OPT -c owner "$GOPW" 
        echo
fi

# clean up any leftover keys on the tpm2go
echo "Cleaning up old keys"
if tpm2_getcap $TCTI_OPT handles-persistent | grep -q 0x81000003 ; then
	tpm2_evictcontrol $TCTI_OPT -C o -c 0x81000003 -P "$GOPW" 
fi
if tpm2_getcap $TCTI_OPT handles-persistent | grep -q 0x81000004 ; then
	tpm2_evictcontrol $TCTI_OPT -C o -c 0x81000004 -P "$GOPW" 
fi

# create SRK at 0x81000003 on the tpm2go
echo "Creating SRK"
echo "SRK" | tpm2_createprimary $TCTI_OPT -c primary.ctx -P "$GOPW" -u -
echo "Making it persistent"
tpm2_flushcontext $TCTI_OPT -t
tpm2_evictcontrol  $TCTI_OPT -C o -c primary.ctx 0x81000003 -P "$GOPW"
tpm2_flushcontext $TCTI_OPT -t

# Create default recoverable storage key (DRSK) persistent at 0x81000004.
# Use a policy that allows duplication, but only with owner password
echo "creating authsession"
tpm2_startauthsession $TCTI_OPT -S session.dat 
tpm2_policycommandcode $TCTI_OPT -S session.dat -L dpolicy.dat TPM2_CC_Duplicate 
tpm2_policysecret $TCTI_OPT -S session.dat -c o -L dpolicy.dat "$GOPW" 
tpm2_flushcontext $TCTI_OPT session.dat 
tpm2_flushcontext $TCTI_OPT -t

echo "creating DRSK"
tpm2_create $TCTI_OPT -C 0x81000003 -r go_drsk.prv -u go_drsk.pub -L dpolicy.dat -a \
	"sensitivedataorigin|userwithauth|restricted|decrypt" 
tpm2_flushcontext $TCTI_OPT -t

# make it persistent
echo "making DRSK persistent"
tpm2_load $TCTI_OPT -C 0x81000003 -u go_drsk.pub -r go_drsk.prv -c go_drsk.ctx 
tpm2_evictcontrol $TCTI_OPT -C o -c go_drsk.ctx 0x81000004 -P "$GOPW" 

# clean up
# rm session.dat dpolicy.dat go_drsk.* primary.ctx
rm *.dat *.ctx
