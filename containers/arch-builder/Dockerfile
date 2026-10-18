FROM archlinux:base-devel

# As this will be an end-use container, not a pre-built one, we can fully initialise and populate the keyring for Arch
# Linux in order for us to download and verify the core and extra packages from the official Arch Linux repositories.
RUN pacman-key --init && pacman-key --populate archlinux

# To allow our own containers to build using our own repository, we need to add our repository's public key to the
# keyring and sign it into the keyring so that pacman can verify the packages we build and host in our own repository.
COPY containers/arch-builder/assets/repository.pub /tmp
RUN pacman-key --add /tmp/repository.pub && \
    pacman-key --lsign-key "0x$(gpg --with-colons --with-fingerprint /tmp/repository.pub 2>/dev/null \
				| awk -F : '/^pub:/ { print $5 }')"

# Update the Pacman configuration to include our own repository, and then update the system to ensure we have the latest
# packages and security updates before pushing the container for Concourse to retrieve.
COPY containers/arch-builder/assets/pacman.conf /etc/pacman.conf
COPY containers/arch-builder/assets/aur /etc/pacman.d/aur
RUN pacman -Syu --noconfirm jq

COPY scripts/bin/arch-builder-build /usr/local/bin/build
COPY scripts/bin/arch-builder-sign /usr/local/bin/sign
COPY scripts/bin/arch-builder-update /usr/local/bin/update
COPY scripts/lib /usr/local/lib

RUN useradd --system --create-home --home-dir /build --skel /dev/null --user-group builder && \
    chown -R builder:builder /tmp/repository.pub

COPY containers/arch-builder/assets/sudoers /etc/sudoers.d/builder

USER builder
WORKDIR /build

# Import the repository public key into the GPG keyring under the builder user in preparation for importing the private
# key for signing packages, but forcefully remove the lock file once done as it will otherwise prevent the importing
RUN gpg --batch --yes --import /tmp/repository.pub && rm -f /build/.gnupg/public-keys.d/pubring.db.lock

ENTRYPOINT ["/usr/local/bin/build"]
