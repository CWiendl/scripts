#!/bin/bash

# 1) Changing all the passwords to "suckzHPCC!" (including root)
echo "Step 1: Changing all user passwords to 'suckzHPCC!'"
USERS=$(getent passwd | awk -F: '($3 >= 1000 || $3 == 0) && ($7 !~ /(nologin|false)$/) {print $1}')
for USER in $USERS; do
    echo "Changing password for user '$USER'"
    echo "$USER:suckzHPCC!" | sudo chpasswd
done

# 2) Removing extra users and their home directories, killing their processes
echo "Step 2: Removing extra users and their home directories, killing their processes"
for USER in $USERS; do
    if [[ "$USER" != "plinktern" && "$USER" != "hkeating" && "$USER" != "root" ]]; then
        echo "Killing all processes for user '$USER'"
        sudo pkill -u "$USER"
        echo "Force removing user '$USER' and their home directory"
        sudo userdel -r -f "$USER"
    fi
done

# Refresh the USERS variable after deleting users
USERS=$(getent passwd | awk -F: '($3 >= 1000 || $3 == 0) && ($7 !~ /(nologin|false)$/) {print $1}')

# 3) (Skipping renaming of 'hkeating')

# 4) Clearing out all SSH authorized keys in every home directory (including root)
echo "Step 3: Clearing out all SSH authorized keys"
for USER in "root" "plinktern" "hkeating"; do
    HOME_DIR=$(eval echo "~$USER")
    AUTH_KEYS_FILE="$HOME_DIR/.ssh/authorized_keys"
    if [ -f "$AUTH_KEYS_FILE" ]; then
        echo "Removing authorized_keys for user '$USER'"
        sudo rm -f "$AUTH_KEYS_FILE"
    else
        echo "No authorized_keys file for user '$USER'"
    fi
done

# 5) Configuring SSH whitelist
echo "Step 4: Configuring SSH whitelist"
SSH_CONFIG="/etc/ssh/sshd_config"
sudo sed -i '/^AllowUsers/d' "$SSH_CONFIG"
echo "AllowUsers plinktern hkeating" | sudo tee -a "$SSH_CONFIG" >/dev/null

# 6) Configuring SSH authentication settings
echo "Step 5: Configuring SSH authentication settings"
sudo sed -i 's/^#*PasswordAuthentication.*/PasswordAuthentication yes/' "$SSH_CONFIG"
sudo sed -i 's/^#*PermitEmptyPasswords.*/PermitEmptyPasswords no/' "$SSH_CONFIG"
sudo sed -i 's/^#*PubkeyAuthentication.*/PubkeyAuthentication no/' "$SSH_CONFIG"
sudo sed -i 's/^#*PermitRootLogin.*/PermitRootLogin no/' "$SSH_CONFIG"
sudo sed -i 's/^#*Protocol.*/Protocol 2/' "$SSH_CONFIG"

# Restart SSH service to apply changes
sudo systemctl restart sshd

# 7) Making SSH configuration files and directory immutable
echo "Step 6: Making SSH configuration files and directory immutable"
sudo chattr -R +i /etc/ssh

# 8) Installing packages: ufw, htop, whowatch, tmux, pspy
echo "Step 7: Installing packages: ufw, htop, whowatch, tmux, pspy"
sudo apt update
sudo apt install -y ufw htop whowatch tmux

# Create a directory for pspy
echo "Downloading pspy tool"
mkdir -p ~/tools/pspy
cd ~/tools/pspy

# Detect system architecture (64-bit or 32-bit)
ARCH=$(uname -m)
if [[ "$ARCH" == "x86_64" ]]; then
    PSPY_BINARY="pspy64"
else
    PSPY_BINARY="pspy32"
fi

# Download the latest pspy release
wget "https://github.com/DominicBreuker/pspy/releases/download/v1.2.1/$PSPY_BINARY" -O pspy
chmod +x pspy

# Return to the home directory
cd ~

# 9) Configuring UFW to allow specific ports
echo "Step 8: Configuring UFW to allow specific ports"
sudo ufw default deny incoming
sudo ufw default allow outgoing
sudo ufw allow ssh
sudo ufw allow http
sudo ufw allow https
sudo ufw allow 3306/tcp  # Assuming MySQL for SQL
sudo ufw --force enable

echo "All steps completed successfully."
