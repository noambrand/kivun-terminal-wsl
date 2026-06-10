#!/bin/bash
# Ensure a non-root user exists and is the WSL default. Distros installed
# non-interactively (`wsl --install --no-launch`, or an offline `--from-file`
# image) skip the first-run account setup and contain ONLY root — and Claude
# Code refuses to run as root (--dangerously-skip-permissions needs a non-root
# user). This left fresh installs unable to launch Claude until the user hand-
# created an account. Run as root. Idempotent — safe to run repeatedly.
U=kivun
id -u "$U" >/dev/null 2>&1 || useradd -m -s /bin/bash "$U"
usermod -aG sudo "$U" 2>/dev/null || true
# Passwordless sudo: the launcher may run `sudo apt-get ...` as this user, and a
# freshly-created account has no password, so a prompt would hang forever.
mkdir -p /etc/sudoers.d
printf '%s\n' "$U ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/90-"$U"
chmod 0440 /etc/sudoers.d/90-"$U"
# Make it the default user so WSLg comes up owned by it (needs a wsl restart to
# take effect). Don't clobber an existing default= the user may have set.
grep -qs '^[[:space:]]*default[[:space:]]*=' /etc/wsl.conf || printf '[user]\ndefault=%s\n' "$U" >> /etc/wsl.conf
echo "KIVUN_USER_READY=$U uid=$(id -u "$U")"
