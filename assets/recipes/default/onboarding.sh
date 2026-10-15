set -e

C_RESET=''
C_RED=''
C_GREEN=''
C_YELLOW=''
C_CYAN=''
C_GREY=''
if [ -r /etc/skel/.config/zsh/lib/colours.sh ]; then
    . /etc/skel/.config/zsh/lib/colours.sh || true
fi

clear
echo "============================================================"
echo "            Welcome to your WSL Stack environment"
echo "============================================================"
echo ""

missing=""
for package in adduser sudo tzdata whiptail; do
    dpkg-query -W -f '${Status}' "$package" 2>/dev/null | grep -q 'install ok installed' || missing="$missing $package"
done
if [ -n "$missing" ]; then
    export DEBIAN_FRONTEND=noninteractive
    echo "${C_CYAN}Installing the onboarding's own tools:$missing${C_RESET}"
    apt-get update -qq
    read -ra needed <<< "$missing"
    apt-get install -y --no-install-recommends "${needed[@]}"
    echo ""
fi

NEW_USER="${1:-}"

while true; do
    if [ -z "$NEW_USER" ]; then
        read -rp "${C_YELLOW}Enter your username: ${C_RESET}" NEW_USER
    fi
    if [[ ! "$NEW_USER" =~ ^[a-z][a-z0-9_-]*$ ]]; then
        echo "${C_YELLOW}Invalid username (lowercase letters, numbers, underscores, and dashes only, starting with a letter).${C_RESET}"
        NEW_USER=''
    elif id "$NEW_USER" >/dev/null 2>&1; then
        echo "${C_YELLOW}The account '$NEW_USER' already exists - pick another name.${C_RESET}"
        NEW_USER=''
    else
        break
    fi
done

echo ""
echo "${C_CYAN}Creating user account $NEW_USER...${C_RESET}"

SHELL_PATH=/usr/bin/zsh
if [ ! -x "$SHELL_PATH" ]; then
    SHELL_PATH=/bin/bash
fi
adduser --disabled-password --gecos "" --shell "$SHELL_PATH" "$NEW_USER"


sed -i '/onboarding\.sh/d' /root/.bashrc 2>/dev/null || true

echo ""

read -rp "${C_YELLOW}Run sudo without a password (passwordless)? [y/N] ${C_RESET}" PASSWORDLESS
echo ""

usermod -aG sudo "$NEW_USER"

PASSWORDLESS_OK=no
if [[ "$PASSWORDLESS" =~ ^[Yy]$ ]]; then

    SUDOERS_FILE="/etc/sudoers.d/010-$NEW_USER-nopasswd"
    echo "$NEW_USER ALL=(ALL) NOPASSWD: ALL" > "$SUDOERS_FILE"
    chmod 0440 "$SUDOERS_FILE"
    if visudo -cf "$SUDOERS_FILE" >/dev/null 2>&1; then
        PASSWORDLESS_OK=yes
        echo "${C_GREEN}sudo will not ask for a password.${C_RESET}"
    else
        rm -f "$SUDOERS_FILE"
        echo "${C_YELLOW}[WARNING] The sudo rule could not be written - falling back to a password.${C_RESET}"
    fi
fi

if [[ "$PASSWORDLESS_OK" == no ]]; then
    echo "${C_YELLOW}Please set a password for $NEW_USER:${C_RESET}"
    while ! passwd "$NEW_USER"; do
        echo ""
        echo "${C_RED}[ERROR] Password setup failed (mismatch or empty). Let's try again.${C_RESET}"
    done
fi

groupadd --force docker
usermod -aG docker "$NEW_USER"

echo ""
echo "${C_CYAN}Configuring timezone...${C_RESET}"

TZ_NAME=$(readlink /etc/localtime 2>/dev/null | sed 's|.*/zoneinfo/||')
if [ -n "$TZ_NAME" ] && [ -f "/usr/share/zoneinfo/$TZ_NAME" ]; then
    debconf-set-selections <<EOF
tzdata tzdata/Areas select ${TZ_NAME%%/*}
tzdata tzdata/Zones/${TZ_NAME%%/*} select ${TZ_NAME#*/}
EOF
    dpkg-reconfigure -f noninteractive tzdata
    echo "${C_GREEN}Timezone: $TZ_NAME (from Windows).${C_RESET}"
else
    dpkg-reconfigure -f dialog tzdata
fi
clear

cat << WSLCONF > /etc/wsl.conf
[user]
default=$NEW_USER

[automount]
enabled=true
mountFsTab=false

[interop]
enabled=true
appendWindowsPath=true
WSLCONF

su - "$NEW_USER" -c "tldr --update" || echo "${C_GREY}  (tldr cache left as it was)${C_RESET}"

if [ "$SHELL_PATH" != /usr/bin/zsh ]; then
    echo ""
    echo "Please wait..."
fi

rm -f /root/onboarding.sh
exit 0
