#!/bin/bash
################################################################################
# Script: ssh_trust_tui.sh
# Desc:   TUI-based SSH passwordless login setup
#   1. Auto-detect hosts from ~/.ssh/config, select and configure in batch
#   2. Manually enter hosts (user@ip format, supports batch/comma-separated)
# Env:    Local = Ubuntu, remote = Ubuntu or CentOS
################################################################################

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

log_info()    { echo -e "${YELLOW}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[OK]${NC} $1"; }
log_error()   { echo -e "${RED}[ERR]${NC} $1"; }

TARGETS=()   # connection targets: config alias, or manual user@ip
PORTS=()     # parallel to TARGETS, e.g. "-p 17022", empty if default port
PASS=""

# Check whiptail, auto-install if missing
check_whiptail() {
    if ! command -v whiptail &>/dev/null; then
        log_info "whiptail not found, installing..."
        sudo apt-get update -y && sudo apt-get install -y whiptail
    fi
}

# Feature 1: scan ~/.ssh/config, list host aliases for selection
scan_ssh_config() {
    local config="$HOME/.ssh/config"
    if [ ! -f "$config" ]; then
        whiptail --msgbox "Not found: $config" 8 50
        return
    fi

    local aliases=()
    while read -r line; do
        for a in $(echo "$line" | awk '{for(i=2;i<=NF;i++) print $i}'); do
            [[ "$a" == *"*"* || "$a" == *"?"* ]] && continue
            aliases+=("$a")
        done
    done < <(grep -i "^[[:space:]]*Host[[:space:]]" "$config")

    if [ ${#aliases[@]} -eq 0 ]; then
        whiptail --msgbox "No valid host alias found in $config (wildcard Host excluded)" 8 60
        return
    fi

    local menu_items=()
    for a in "${aliases[@]}"; do
        local hostname user port desc
        hostname=$(ssh -G "$a" 2>/dev/null | awk '/^hostname /{print $2; exit}')
        user=$(ssh -G "$a" 2>/dev/null | awk '/^user /{print $2; exit}')
        port=$(ssh -G "$a" 2>/dev/null | awk '/^port /{print $2; exit}')
        desc="${user}@${hostname}:${port}"
        menu_items+=("$a" "$desc" "OFF")
    done

    local selected
    selected=$(whiptail --checklist "Hosts found in ~/.ssh/config, SPACE to select, TAB to switch, ENTER to confirm:" 20 76 10 \
        "${menu_items[@]}" 3>&1 1>&2 2>&3)

    if [ -n "$selected" ]; then
        eval "sel_array=($selected)"
        for s in "${sel_array[@]}"; do
            TARGETS+=("$s")
            PORTS+=("")   # alias resolves port via config itself, no explicit -p needed
        done
        whiptail --msgbox "Added ${#sel_array[@]} host(s)" 8 40
    fi
}

# Feature 1b: add host(s) into ~/.ssh/config, so they show up under Feature 1
add_to_ssh_config() {
    local config="$HOME/.ssh/config"
    mkdir -p "$HOME/.ssh"
    chmod 700 "$HOME/.ssh"
    touch "$config"
    chmod 600 "$config"

    whiptail --msgbox "Switching to terminal input mode:\nOne host per line: ALIAS user@ip [-p PORT]\nExample: web1 root@172.16.143.4 -p 17022\nEmpty line to finish." 12 66
    echo ""
    log_info "Enter entries as: ALIAS user@ip [-p PORT]  (empty line to finish)"
    local added=0
    while IFS= read -r line; do
        [ -z "$line" ] && break
        line="$(echo "$line" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')"
        [ -z "$line" ] && continue

        if [[ "$line" =~ ^([^[:space:]]+)[[:space:]]+([^[:space:]@]+)@([^[:space:]]+)([[:space:]]+-p[[:space:]]+([0-9]+))?$ ]]; then
            local alias="${BASH_REMATCH[1]}"
            local ruser="${BASH_REMATCH[2]}"
            local rhost="${BASH_REMATCH[3]}"
            local rport="${BASH_REMATCH[5]:-22}"

            if grep -qi "^[[:space:]]*Host[[:space:]]\+${alias}[[:space:]]*$" "$config"; then
                log_error "Alias '$alias' already exists in config, skipped"
                continue
            fi

            {
                echo ""
                echo "Host $alias"
                echo "    HostName $rhost"
                echo "    User $ruser"
                echo "    Port $rport"
            } >> "$config"

            log_success "Added '$alias' -> ${ruser}@${rhost}:${rport}"
            ((added++))
        else
            log_error "Invalid format, skipped: $line"
        fi
    done
    chmod 600 "$config"
    echo ""
    log_success "Done. $added entrie(s) added to $config"
    log_info "Use 'Auto-detect hosts from ~/.ssh/config' to select them"
    log_info "Press Enter to return to menu..."
    read -r
}

# Helper: locate the line range of a "Host ALIAS" block in ~/.ssh/config
# Sets BLOCK_START / BLOCK_END on success, returns 1 if alias not found
get_block_range() {
    local alias="$1"
    local config="$HOME/.ssh/config"

    BLOCK_START=$(grep -n -i "^[[:space:]]*Host[[:space:]]\+${alias}[[:space:]]*$" "$config" | head -1 | cut -d: -f1)
    [ -z "$BLOCK_START" ] && return 1

    local total
    total=$(wc -l < "$config")
    BLOCK_END=$total

    local next
    next=$(awk -v start="$BLOCK_START" 'NR>start && $1=="Host"{print NR; exit}' "$config")
    [ -n "$next" ] && BLOCK_END=$((next - 1))

    return 0
}

# Edit a single "Host ALIAS" block (rewrites it as HostName/User/Port only)
edit_ssh_config_entry() {
    local alias="$1"
    local config="$HOME/.ssh/config"

    if ! get_block_range "$alias"; then
        whiptail --msgbox "Could not locate block for '$alias'" 8 50
        return
    fi

    local block cur_hostname cur_user cur_port
    block=$(sed -n "${BLOCK_START},${BLOCK_END}p" "$config")
    cur_hostname=$(echo "$block" | awk '/^[[:space:]]*HostName[[:space:]]+/{print $2; exit}')
    cur_user=$(echo "$block" | awk '/^[[:space:]]*User[[:space:]]+/{print $2; exit}')
    cur_port=$(echo "$block" | awk '/^[[:space:]]*Port[[:space:]]+/{print $2; exit}')
    [ -z "$cur_port" ] && cur_port="22"

    whiptail --msgbox "Note: saving will rewrite this block with only Alias/HostName/User/Port.\nAny other custom options in this block will be removed." 10 62

    local new_alias new_hostname new_user new_port
    new_alias=$(whiptail --inputbox "Alias:" 8 60 "$alias" 3>&1 1>&2 2>&3) || return
    [ -z "$new_alias" ] && { whiptail --msgbox "Alias cannot be empty" 8 40; return; }

    if [ "$new_alias" != "$alias" ] && grep -qi "^[[:space:]]*Host[[:space:]]\+${new_alias}[[:space:]]*$" "$config"; then
        whiptail --msgbox "Alias '$new_alias' already exists" 8 50
        return
    fi

    new_hostname=$(whiptail --inputbox "HostName (IP/domain):" 8 60 "$cur_hostname" 3>&1 1>&2 2>&3) || return
    new_user=$(whiptail --inputbox "User:" 8 60 "$cur_user" 3>&1 1>&2 2>&3) || return
    new_port=$(whiptail --inputbox "Port:" 8 60 "$cur_port" 3>&1 1>&2 2>&3) || return

    if [ -z "$new_hostname" ] || [ -z "$new_user" ] || [ -z "$new_port" ]; then
        whiptail --msgbox "HostName/User/Port cannot be empty" 8 50
        return
    fi

    {
        head -n $((BLOCK_START - 1)) "$config"
        echo "Host $new_alias"
        echo "    HostName $new_hostname"
        echo "    User $new_user"
        echo "    Port $new_port"
        tail -n +$((BLOCK_END + 1)) "$config"
    } > "${config}.tmp" && mv "${config}.tmp" "$config"
    chmod 600 "$config"

    whiptail --msgbox "Updated: Host $new_alias (${new_user}@${new_hostname}:${new_port})" 8 60
}

# Delete a single "Host ALIAS" block from ~/.ssh/config
delete_ssh_config_entry() {
    local alias="$1"
    local config="$HOME/.ssh/config"

    if ! get_block_range "$alias"; then
        whiptail --msgbox "Could not locate block for '$alias'" 8 50
        return
    fi

    whiptail --yes-button "Yes" --no-button "No" --yesno "Delete host '$alias' from ~/.ssh/config?\nThis cannot be undone." 10 55
    [ $? -ne 0 ] && return

    {
        head -n $((BLOCK_START - 1)) "$config"
        tail -n +$((BLOCK_END + 1)) "$config"
    } > "${config}.tmp" && mv "${config}.tmp" "$config"
    chmod 600 "$config"

    whiptail --msgbox "Deleted '$alias' from $config" 8 50
}

# Feature 1c: browse ~/.ssh/config entries, edit or delete one at a time
manage_ssh_config_entries() {
    local config="$HOME/.ssh/config"
    if [ ! -f "$config" ]; then
        whiptail --msgbox "Not found: $config" 8 50
        return
    fi

    while true; do
        local aliases=()
        while read -r line; do
            for a in $(echo "$line" | awk '{for(i=2;i<=NF;i++) print $i}'); do
                [[ "$a" == *"*"* || "$a" == *"?"* ]] && continue
                aliases+=("$a")
            done
        done < <(grep -i "^[[:space:]]*Host[[:space:]]" "$config")

        if [ ${#aliases[@]} -eq 0 ]; then
            whiptail --msgbox "No editable host alias found in $config" 8 60
            return
        fi

        local menu_items=()
        for a in "${aliases[@]}"; do
            local hostname user port desc
            hostname=$(ssh -G "$a" 2>/dev/null | awk '/^hostname /{print $2; exit}')
            user=$(ssh -G "$a" 2>/dev/null | awk '/^user /{print $2; exit}')
            port=$(ssh -G "$a" 2>/dev/null | awk '/^port /{print $2; exit}')
            desc="${user}@${hostname}:${port}"
            menu_items+=("$a" "$desc")
        done

        local pick
        pick=$(whiptail --menu "Select a host entry to edit or delete:" 20 70 10 "${menu_items[@]}" 3>&1 1>&2 2>&3)
        [ $? -ne 0 ] && return
        [ -z "$pick" ] && return

        local action
        action=$(whiptail --menu "Host: $pick" 12 50 2 \
            "EDIT" "Edit this entry" \
            "DELETE" "Delete this entry" 3>&1 1>&2 2>&3)
        [ $? -ne 0 ] && continue

        case "$action" in
            EDIT)   edit_ssh_config_entry "$pick" ;;
            DELETE) delete_ssh_config_entry "$pick" ;;
        esac
    done
}

# Supported formats:
#   user@ip
#   user@ip -p 2222   (custom port, whitespace-insensitive)
parse_host_entry() {
    local entry="$1"
    entry="$(echo "$entry" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')"
    [ -z "$entry" ] && return 1

    if [[ "$entry" =~ ^(.+[^[:space:]])[[:space:]]+-p[[:space:]]+([0-9]+)$ ]]; then
        PARSED_HOST="${BASH_REMATCH[1]}"
        PARSED_PORT="-p ${BASH_REMATCH[2]}"
    else
        PARSED_HOST="$entry"
        PARSED_PORT=""
    fi
    return 0
}

# Feature 2: manual batch host input (session-only, NOT saved to ~/.ssh/config)
manual_input() {
    whiptail --msgbox "Switching to terminal input mode (fallback, session-only, not saved to ~/.ssh/config):\nOne or more hosts per line, comma-separated for multiple.\nFormat: user@ip  or  user@ip -p PORT\nEmpty line to finish." 13 66
    echo ""
    log_info "Enter hosts (comma-separated, supports user@ip -p PORT, empty line to finish):"
    local count=0
    while IFS= read -r line; do
        [ -z "$line" ] && break
        # split only on comma, keep internal spaces (e.g. -p PORT) intact
        IFS=',' read -ra entries <<< "$line"
        for e in "${entries[@]}"; do
            if parse_host_entry "$e"; then
                TARGETS+=("$PARSED_HOST")
                PORTS+=("$PARSED_PORT")
                ((count++))
            fi
        done
    done
    log_success "Added $count host(s)"
}

# Remove selected host(s) from the list (multi-select)
remove_targets() {
    if [ ${#TARGETS[@]} -eq 0 ]; then
        whiptail --msgbox "List is empty, nothing to remove" 8 40
        return
    fi

    local menu_items=()
    for i in "${!TARGETS[@]}"; do
        local desc="${TARGETS[$i]}"
        [ -n "${PORTS[$i]}" ] && desc="${TARGETS[$i]} (${PORTS[$i]})"
        menu_items+=("$i" "$desc" "OFF")
    done

    local selected
    selected=$(whiptail --checklist "Select host(s) to remove, SPACE to select, ENTER to confirm:" 20 70 10 \
        "${menu_items[@]}" 3>&1 1>&2 2>&3)

    [ $? -ne 0 ] && return   # user cancelled
    [ -z "$selected" ] && { whiptail --msgbox "No host selected, nothing removed" 8 40; return; }

    eval "del_indexes=($selected)"

    local -A to_delete
    for idx in "${del_indexes[@]}"; do
        to_delete[$idx]=1
    done

    local new_targets=()
    local new_ports=()
    for i in "${!TARGETS[@]}"; do
        if [ -z "${to_delete[$i]}" ]; then
            new_targets+=("${TARGETS[$i]}")
            new_ports+=("${PORTS[$i]}")
        fi
    done
    TARGETS=("${new_targets[@]}")
    PORTS=("${new_ports[@]}")

    whiptail --msgbox "Removed ${#del_indexes[@]} host(s), ${#TARGETS[@]} remaining" 8 50
}

# Dedupe (key = target + port combo)
dedupe_targets() {
    local -A seen
    local uniq_t=()
    local uniq_p=()
    for i in "${!TARGETS[@]}"; do
        local key="${TARGETS[$i]}|${PORTS[$i]}"
        if [ -z "${seen[$key]}" ]; then
            seen[$key]=1
            uniq_t+=("${TARGETS[$i]}")
            uniq_p+=("${PORTS[$i]}")
        fi
    done
    TARGETS=("${uniq_t[@]}")
    PORTS=("${uniq_p[@]}")
}

# Generate local SSH key
generate_local_key() {
    if [ ! -f ~/.ssh/id_rsa.pub ]; then
        log_info "No local SSH key found, generating..."
        ssh-keygen -t rsa -N "" -f ~/.ssh/id_rsa -q
        log_success "Local key generated"
    else
        log_success "Local key already exists, skipping"
    fi
}

check_sshpass() {
    if [ -n "$PASS" ] && ! command -v sshpass &>/dev/null; then
        log_info "sshpass required, installing..."
        sudo apt-get update -y && sudo apt-get install -y sshpass
    fi
}

distribute_keys() {
    for i in "${!TARGETS[@]}"; do
        local HOST="${TARGETS[$i]}"
        local PORT="${PORTS[$i]}"
        local LABEL="$HOST"; [ -n "$PORT" ] && LABEL="$HOST ($PORT)"
        log_info "Configuring: $LABEL"
        if [ -n "$PASS" ]; then
            sshpass -p "$PASS" ssh-copy-id -o StrictHostKeyChecking=no $PORT "$HOST"
        else
            ssh-copy-id -o StrictHostKeyChecking=no $PORT "$HOST"
        fi
        if [ $? -eq 0 ]; then
            log_success "$LABEL key distributed"
        else
            log_error "$LABEL key distribution failed"
        fi
    done
}

verify_trust() {
    log_info "Verifying passwordless login..."
    for i in "${!TARGETS[@]}"; do
        local HOST="${TARGETS[$i]}"
        local PORT="${PORTS[$i]}"
        local LABEL="$HOST"; [ -n "$PORT" ] && LABEL="$HOST ($PORT)"
        RESULT=$(ssh -o BatchMode=yes -o ConnectTimeout=5 $PORT "$HOST" "echo OK" 2>/dev/null)
        if [ "$RESULT" == "OK" ]; then
            log_success "$LABEL verified OK"
        else
            log_error "$LABEL verification failed"
        fi
    done
}

run_config() {
    if [ ${#TARGETS[@]} -eq 0 ]; then
        whiptail --msgbox "No hosts added yet, please select or enter hosts first" 8 50
        return
    fi

    dedupe_targets

    local summary=""
    for i in "${!TARGETS[@]}"; do
        if [ -n "${PORTS[$i]}" ]; then
            summary+="${TARGETS[$i]} (${PORTS[$i]})\n"
        else
            summary+="${TARGETS[$i]}\n"
        fi
    done
    whiptail --yes-button "Yes" --no-button "No" --yesno "About to configure passwordless login for ${#TARGETS[@]} host(s):\n\n$summary\nContinue?" 20 60
    [ $? -ne 0 ] && return

    if whiptail --yes-button "Yes" --no-button "No" --defaultno --yesno "Use one shared password for all hosts (for auto distribution)?\nChoose No to enter password per-host manually" 10 60; then
        PASS=$(whiptail --passwordbox "Enter shared password:" 8 50 3>&1 1>&2 2>&3)
    fi

    clear
    echo "================================================"
    echo "   Starting SSH passwordless login setup"
    echo "================================================"
    generate_local_key
    check_sshpass
    distribute_keys
    verify_trust
    echo ""
    log_info "Setup finished, exiting TUI"
    exit 0
}

main_menu() {
    while true; do
        CHOICE=$(whiptail --title "SSH Trust Setup" --menu "Choose an action:" 21 66 9 \
            "1" "Auto-detect hosts from ~/.ssh/config" \
            "2" "Add host(s) to ~/.ssh/config" \
            "3" "Edit/Delete host(s) in ~/.ssh/config" \
            "4" "Manually enter hosts (fallback, session-only)" \
            "5" "View selected hosts (${#TARGETS[@]})" \
            "6" "Remove host(s) from selection" \
            "7" "Clear selection" \
            "8" "Start setup" \
            "9" "Exit" 3>&1 1>&2 2>&3)

        case "$CHOICE" in
            1) scan_ssh_config ;;
            2) add_to_ssh_config ;;
            3) manage_ssh_config_entries ;;
            4) manual_input ;;
            5)
                if [ ${#TARGETS[@]} -eq 0 ]; then
                    whiptail --msgbox "List is empty" 8 40
                else
                    local list=""
                    for i in "${!TARGETS[@]}"; do
                        if [ -n "${PORTS[$i]}" ]; then
                            list+="${TARGETS[$i]} (${PORTS[$i]})\n"
                        else
                            list+="${TARGETS[$i]}\n"
                        fi
                    done
                    whiptail --msgbox "$list" 20 60
                fi
                ;;
            6) remove_targets ;;
            7) TARGETS=(); PORTS=(); whiptail --msgbox "Cleared" 8 30 ;;
            8) run_config ;;
            9|"") clear; exit 0 ;;
        esac
    done
}

check_whiptail
main_menu
