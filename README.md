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

NOTE: provision.sh will set an owner password, which causes problems
with systemd-cryptenroll. Apply the supplied srk_handle.patch to
the upstream systemd to add a --tpm2-srk-handle= argument. Then
after provisioning, you can set --tpm2-srk-handle=0x81000004 to
use the recoverable DRSK as storage root.

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
has not made it downstream. To add this support, built the upstream version with:

    sudo dnf install libtool automake autoconf autoconf-archive libusb1-devel
    sudo dnf builddep tpm2-tss
    git clone https://github.com/tpm2-software/tpm2-tss.git
    cd tpm2-tss
    ./bootstrap
    ./configure --prefix=/usr --enable-tcti_spi_ltt2go
    make
    sudo make install


