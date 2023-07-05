#! /bin/bash
#
# ./backup.sh <server name or IP address>
# backup my DRSK to the server's DRSK

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

# all the rest are fixed relative to BASEDIR
LOCALDIR=$BASEDIR/my_keys
MYBACKUPDIR=$BASEDIR/servers/$SERVERADDR
MYID=`cat $LOCALDIR/myid`
SERVERBACKUPDIR=$BASEDIR/clients/$MYID

# Do the backup in my local backup directory for this specific server
mkdir -p $MYBACKUPDIR
cd $MYBACKUPDIR

# get the server's DRSK public key
scp $SERVERADDR:$LOCALDIR/my_drsk.pub server.pub

# create dup.pub dup.dpriv and dup.seed from my DRSK
cp $LOCALDIR/* .
cp my_drsk.pub dup.pub
IFS= read -r -s -p "Enter this client's existing TPM owner password: " OPW
tpm2_startauthsession --policy-session -S session.dat 
tpm2_policycommandcode -S session.dat -L dpolicy.dat TPM2_CC_Duplicate 
tpm2_policysecret -S session.dat -c o -L dpolicy.dat "$OPW"
tpm2_loadexternal -C o -u server.pub -c server.ctx
tpm2_duplicate -C server.ctx -c 0x81000004 -G null -p "session:session.dat" -r dup.dpriv -s dup.seed 
tpm2_flushcontext session.dat 
rm session.dat

# send dup.pub, dup.dpriv, dup.seed to server
ssh $SERVERADDR mkdir -p $SERVERBACKUPDIR
scp dup.pub dup.dpriv dup.seed $SERVERADDR:$SERVERBACKUPDIR
IFS= read -r -s -p "Enter the server's existing TPM owner password: " SOPW
ssh $SERVERADDR $BASEDIR/bin/server_backup.sh $MYID $SOPW

# clean up
rm server.ctx dpolicy.dat

