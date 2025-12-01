This package demonstrates a simple recovery mechanism for data across a 
TPM (or motherboard) failure. See tpm_keys/docs/tpm_keys.pdf for details

Typical Installation:

cd

git clone https://github.com/safforddr/tpm_keys.git

cd tpm_keys

sudo cp -r tpm_keys /boot

sudo chown -R $USERNAME:tss /boot/tpm_keys

cd /boot/tpm_keys/bin

./provision.sh

NOTE: systemd-cryptenroll has a --tpm2-seal-key-handle=
argument which allows the use of a persistent SRK, as
described in this package. Unfortunately, it does not work
with a recoverable DRSK, as cryptenroll still insists on the
sealed blob being FIXEDTPM, which will not load under a DRSK.
The suppplied patch cryptenroll-recovery.patch is a tiny patch
to cryptenroll that checks to see if the key pointed to by 
--tpm2-seal-key-handle is recoverable. If so, it removes the FIXEDTPM
attribute from the blob to be sealed. To compile the patch, download
your current systemd sources (adjust the following commands to match
your current version in place of the shown "257.9-2.fc42"):

	$ dnf download --source systemd	
	$ rpm -i systemd-257.9-2.fc42.src.rpm
	$ cp cryptenroll-recovery.patch ~/rpmbuild/SOURCES	
	$ cd ~/rpmbuild/SPECS
	$ sudo dnf builddep systemd	
	$ vi systemd.spec
		add the following line after the last existing Patch statement (and its #endif).
		
		Patch: 		cryptenroll-recovery.patch		
		
	$ rpmbuild -bb systemd.spec
	
    Reinstall just the libsystemd-shared library, which is all that changed
        $ cd ~/rpmbuild/RPMS/x86_64
        $ sudo rpm --reinstall systemd-shared-257.9-2fc42.x86_64.rpm
        

NEW: This package now supports backups to a local tpm2go device,
as well as remote systems with TPMs. (A tpm2go is a USB token with
an Infineon discrete TPM built in, making it ideal for backup/restore.)

There are separate scripts for provisioning a tpm2go, and for using it 
to backup and restore the local TPM. A typical usage would be:

    provision.sh            # provision the local TPM
    
    tpm2go_provision.sh     # provision the tpm2go device

    tpm2go_backup.sh        # backup the local TPM's DRSK to the tpm2go
    
    tpm2go_restore.sh       # restore the local TPM's DRSK from the tpm2go
    
The tpm2go support in tpm2-tss is upstream in the master, but (as of Fedora 39)
has not made it downstream. To add this support, build the upstream version with:

    sudo dnf install libtool automake autoconf autoconf-archive libusb1-devel
    sudo dnf builddep tpm2-tss
    git clone https://github.com/tpm2-software/tpm2-tss.git
    cd tpm2-tss
    ./bootstrap
    ./configure --prefix=/usr --enable-tcti_spi_ltt2go
    make
    sudo make install

Note that the tpm2-tss support for tpm2go seems to throw occasional timeout errors, 
but everything still works. I'm working that separately with the tpm2-tss team.
