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
mkdir $MYBACKUPDIR
cd $MYBACKUPDIR

# get the server's DRSK public key
scp $SERVERADDR:$LOCALDIR/my_drsk.pub server.pub

# create dup.pub dup.dpriv and dup.seed from my DRSK
cp $LOCALDIR/* .
cp my_drsk.pub dup.pub
tpm2_startauthsession --policy-session -S session.dat 
tpm2_policycommandcode -S session.dat -L policy.dat TPM2_CC_Duplicate 
tpm2_loadexternal -C o -u server.pub -c server.ctx
tpm2_duplicate -C server.ctx -c my_drsk.ctx -G null -p "session:session.dat" -r dup.dpriv -s dup.seed 
tpm2_flushcontext session.dat 

# send dup.pub, dup.dpriv, dup.seed to server
ssh $SERVERADDR mkdir $SERVERBACKUPDIR
scp dup.pub dup.dpriv dup.seed $SERVERADDR:$SERVERBACKUPDIR
ssh $SERVERADDR $BASEDIR/bin/server_backup.sh $MYID

