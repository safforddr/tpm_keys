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
