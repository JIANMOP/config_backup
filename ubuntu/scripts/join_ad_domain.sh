#!/usr/bin/env bash
#
# join_ad_domain.sh
# Purpose: Join an Ubuntu host to a Windows AD domain (based on realmd + sssd)
# Usage:   sudo ./join_ad_domain.sh
#
# Before running, edit the variables in the "===== CONFIG ====" section below.

set -euo pipefail

# ========================= CONFIG =========================

# AD domain name (lowercase)
AD_DOMAIN="evas.ai"

# Kerberos realm for the AD domain (usually the domain name in uppercase)
KRB5_REALM="EVAS.AI"

# AD admin account used to join the domain (you will be prompted for the
# password at join time; never hardcode the password in this script)
JOIN_USER="dawei.wang"

# Domain controller FQDN (used for realm discover verification, optional)
DC_HOST="dc01.evas.ai"

# Domain users allowed to log in to this host (enforced via access_provider=simple)
# ALLOWED_USERS=("dawei.wang" "whitney.yang")
ALLOWED_USERS=("dawei.wang")

# Users granted full sudo privileges (written to /etc/sudoers.d/ad_admins)
# SUDO_USERS=("dawei.wang" "roger.zhang")
SUDO_USERS=("dawei.wang")

# Default login shell
DEFAULT_SHELL="/bin/bash"

# ============================================================

log()  { echo -e "\033[1;32m[INFO]\033[0m $*"; }
warn() { echo -e "\033[1;33m[WARN]\033[0m $*"; }
err()  { echo -e "\033[1;31m[ERROR]\033[0m $*" >&2; }

require_root() {
    if [[ $EUID -ne 0 ]]; then
        err "Please run this script with sudo or as root"
        exit 1
    fi
}

check_dns() {
    log "Current DNS server configuration:"
    resolvectl --no-pager | grep -i "server" || warn "No DNS server detected, please verify the domain controller (${DC_HOST}) can be resolved"
}

install_packages() {
    log "Installing realmd / sssd dependencies..."
    apt update
    apt install -y realmd sssd sssd-tools libnss-sss libpam-sss adcli krb5-user packagekit
}

discover_domain() {
    log "Discovering domain controller ${DC_HOST} ..."
    if ! realm discover "${DC_HOST}"; then
        err "Could not discover domain ${DC_HOST}; check DNS/network reachability to the domain controller"
        exit 1
    fi
}

join_domain() {
    if realm list | grep -q "^${AD_DOMAIN}$"; then
        warn "Host is already joined to domain ${AD_DOMAIN}, skipping realm join"
        return
    fi
    log "Joining domain ${AD_DOMAIN} (you will be prompted for ${JOIN_USER}'s domain password)..."
    realm join -U "${JOIN_USER}" "${AD_DOMAIN}"
}

configure_pam() {
    log "Configuring PAM (including automatic home directory creation via mkhomedir)..."
    pam-auth-update --enable mkhomedir
}

write_sssd_conf() {
    local conf="/etc/sssd/sssd.conf"
    log "Backing up and writing ${conf} ..."
    if [[ -f "${conf}" ]]; then
        cp -a "${conf}" "${conf}.bak.$(date +%Y%m%d%H%M%S)"
    fi

    local allow_users_line
    allow_users_line=$(IFS=,; echo "${ALLOWED_USERS[*]}")

    cat > "${conf}" <<EOF
[sssd]
domains = ${AD_DOMAIN}
config_file_version = 2
services = nss, pam

[domain/${AD_DOMAIN}]
default_shell = ${DEFAULT_SHELL}
krb5_store_password_if_offline = True
cache_credentials = True
krb5_realm = ${KRB5_REALM}
realmd_tags = manages-system joined-with-adcli
id_provider = ad
fallback_homedir = /home/%u
ad_domain = ${AD_DOMAIN}
use_fully_qualified_names = False
ldap_id_mapping = True
access_provider = simple
simple_allow_users = ${allow_users_line}
EOF

    chmod 600 "${conf}"
    chown root:root "${conf}"
}

restart_sssd() {
    log "Restarting sssd and enabling it on boot..."
    systemctl restart sssd
    systemctl enable sssd
}

permit_users() {
    log "Permitting specified domain users to log in to this host (realm permit)..."
    realm permit "${ALLOWED_USERS[@]}"
}

grant_sudo() {
    local sudo_file="/etc/sudoers.d/ad_admins"
    log "Writing sudo privileges to ${sudo_file} ..."

    # Ensure includedir is enabled in the main sudoers file
    # (already present by default on most Ubuntu installs; this is an idempotent check)
    if ! grep -q "^@includedir /etc/sudoers.d" /etc/sudoers; then
        echo "@includedir /etc/sudoers.d" >> /etc/sudoers
    fi

    {
        for u in "${SUDO_USERS[@]}"; do
            echo "${u} ALL=(ALL) ALL"
        done
    } > "${sudo_file}.tmp"

    chmod 440 "${sudo_file}.tmp"
    # Validate syntax to avoid breaking sudo entirely with an invalid file
    if visudo -c -f "${sudo_file}.tmp"; then
        mv "${sudo_file}.tmp" "${sudo_file}"
        log "Sudo privileges written successfully for: ${SUDO_USERS[*]}"
    else
        err "sudoers syntax check failed, ${sudo_file} was not written, please review"
        rm -f "${sudo_file}.tmp"
        exit 1
    fi
}

verify() {
    log "===== Verification ====="
    realm list
    echo
    for u in "${ALLOWED_USERS[@]}"; do
        echo "--- id ${u} ---"
        id "${u}" || warn "Lookup for ${u} failed; you may need to wait for sssd caching or try again after logging in"
    done
}

main() {
    require_root
    check_dns
    install_packages
    discover_domain
    join_domain
    configure_pam
    write_sssd_conf
    restart_sssd
    permit_users
    grant_sudo
    verify

    log "All done. Add domain users later, e.g.:"
    echo "sudo realm permit ${ALLOWED_USERS[0]}"
}

main "$@"
