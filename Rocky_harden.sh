#!/bin/bash

# 1) Changing all the passwords to "suckzHPCC!" (including root)
echo "Step 1: Changing all user passwords to 'suckzHPCC!'"
USERS=$(getent passwd | awk -F: '($3 >= 1000 || $3 == 0) && ($7 !~ /(nologin|false|sync|halt|shutdown)$/) {print $1}')
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
USERS=$(getent passwd | awk -F: '($3 >= 1000 || $3 == 0) && ($7 !~ /(nologin|false|sync|halt|shutdown)$/) {print $1}')

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
sudo dnf install -y epel-release
sudo dnf install -y ufw htop whowatch tmux wget

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
sudo ufw allow ftp
sudo ufw --force enable

# 10) Making backup of '/var/ftp/ImaHorse.jpg' to '~/.backups' and '/opt/.backups'
echo "Step 9: Making backup of '/var/ftp/ImaHorse.jpg'"
BACKUP_DIR1="$HOME/.backups"
BACKUP_DIR2="/opt/.backups"
sudo mkdir -p "$BACKUP_DIR1" "$BACKUP_DIR2"
sudo cp "/var/ftp/ImaHorse.jpg" "$BACKUP_DIR1/"
sudo cp "/var/ftp/ImaHorse.jpg" "$BACKUP_DIR2/"

# Making backups immutable
echo "Step 10: Making backups of 'ImaHorse.jpg' immutable"
sudo chattr +i "$BACKUP_DIR1/ImaHorse.jpg"
sudo chattr +i "$BACKUP_DIR2/ImaHorse.jpg"

# 11) Making '/var/ftp/ImaHorse.jpg' immutable
echo "Step 11: Making '/var/ftp/ImaHorse.jpg' immutable"
sudo chattr +i "/var/ftp/ImaHorse.jpg"

# 12) Configuring FTP server for anonymous read-only access
echo "Step 12: Configuring FTP server for anonymous read-only access"
# Assuming vsftpd is already installed

# Backup original vsftpd configuration
sudo cp /etc/vsftpd/vsftpd.conf /etc/vsftpd/vsftpd.conf.bak

# Configure vsftpd
sudo sed -i 's/^#*anonymous_enable=.*/anonymous_enable=YES/' /etc/vsftpd/vsftpd.conf
sudo sed -i 's/^#*local_enable=.*/local_enable=NO/' /etc/vsftpd/vsftpd.conf
sudo sed -i 's/^#*write_enable=.*/write_enable=NO/' /etc/vsftpd/vsftpd.conf
sudo sed -i 's/^#*anon_upload_enable=.*/anon_upload_enable=NO/' /etc/vsftpd/vsftpd.conf
sudo sed -i 's/^#*anon_mkdir_write_enable=.*/anon_mkdir_write_enable=NO/' /etc/vsftpd/vsftpd.conf
sudo sed -i 's/^#*anon_other_write_enable=.*/anon_other_write_enable=NO/' /etc/vsftpd/vsftpd.conf
sudo sed -i 's/^#*anon_world_readable_only=.*/anon_world_readable_only=YES/' /etc/vsftpd/vsftpd.conf

# Set permissions on /var/ftp
sudo chown ftp:ftp /var/ftp
sudo chmod 555 /var/ftp

# Restart vsftpd service
sudo systemctl restart vsftpd

# Enable vsftpd to start on boot
sudo systemctl enable vsftpd

# Make vsftpd configuration directory immutable
echo "Step 13: Making vsftpd configuration directory immutable"
sudo chattr -R +i /etc/vsftpd

echo "All steps completed successfully."
