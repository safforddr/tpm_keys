#! /bin/bash
#  restore.sh <recovery server name or IP address>
#  This reprovisions the local system by recovering the DRSK.

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
        IFS= read -r -s -p 'Your (New?) TPM has no owner password. Enter a new one: ' OPW
        tpm2_changeauth -c owner "$OPW"
        echo
fi

# all the rest are fixed relative to BASEDIR
LOCALDIR=$BASEDIR/my_keys
MYBACKUPDIR=$BASEDIR/servers/$SERVERADDR
MYID=`cat $LOCALDIR/myid`
SERVERBACKUPDIR=$BASEDIR/clients/$MYID

# Do the restore in my local backup directory for this specific server
mkdir -p $MYBACKUPDIR
cd $MYBACKUPDIR

# clean up any leftover keys
tpm2_evictcontrol -C o -c 0x81000003 -P "$OPW"
tpm2_evictcontrol -C o -c 0x81000004 -P "$OPW"

# create new SRK2 - We use "SRK2" to make a different SRK for demo purposes
echo "SRK2" | tpm2_createprimary -c primary.ctx -P "$OPW" -u - 
tpm2_evictcontrol -C o -c primary.ctx 0x81000003 -P "$OPW"
tpm2_readpublic -c 0x81000003 -o srk2.pub

# recover original DRSK from server
#     send new srk2.pub to server
scp srk2.pub $SERVERADDR:$SERVERBACKUPDIR
#     run server_restore.sh on server to duplicate DRSK under new srk2
IFS= read -r -s -p "Enter the server's existing TPM owner password: " SOPW
ssh $SERVERADDR $BASEDIR/bin/server_restore.sh $MYID $SOPW
#     copy recover.dpriv, recover.pub, recover.seed back
scp $SERVERADDR:$SERVERBACKUPDIR/recover.* .

# import recovery key back to DRSK and make persistent
# Use a policy that allows duplication
tpm2_startauthsession -S session.dat
tpm2_policycommandcode -S session.dat -L dpolicy.dat TPM2_CC_Duplicate
tpm2_policysecret -S session.dat -c o -L dpolicy.dat "$OPW"
tpm2_flushcontext session.dat
tpm2_import -C 0x81000003 -u recover.pub -i recover.dpriv -r recover.prv -s recover.seed -L dpolicy.dat
tpm2_flushcontext --transient-object
tpm2_load -C 0x81000003 -u recover.pub -r recover.prv -c recover.ctx
tpm2_evictcontrol -C o -c recover.ctx 0x81000004 -P "$OPW"

# copy all the recovered files to MY_KEYS
# (recover.pub should be identical to my_drsk.pub, but the others changed due to the new SRK)
cp recover.prv $LOCALDIR/my_drsk.prv
cp recover.pub $LOCALDIR/my_drsk.pub

# clean up
rm -f primary.ctx recover.ctx dpolicy.dat session.dat

