#!/bin/bash
# Custom Arch linux system installation script (userspace)
# by Jure Vidmar

# Execute with (needs root privileges):
# $ ./install_userspace.sh <user>

# Bash flags (https://bash-prompt.net/guides/bash-set-options/)
set -xeuo pipefail

[[ $EUID -ne 0 ]] && echo "This script must be run as root." && exit 1
[ -z "$1" ]       && echo "Usage: $0 <user>"                 && exit 1

exec 1> >(tee "install_userspace_stdout.log")
exec 2> >(tee "install_userspace_stderr.log")

# Add jurepo (custom package repository) to pacman.conf
cat << EOF >> /etc/pacman.conf
[jurepo]
SigLevel = Optional TrustAll
Server   = https://jursaws.s3.eu-west-3.amazonaws.com/jurepo
EOF

# Install packages
pacman -Syu jur-userspace || exit 1


# Install dotfiles and themes
runuser $1 <<- 'HEREDOC'
    DIR_NAME=.dotfiles_git
    git clone --bare https://github.com/jurc192/dotfiles.git $HOME/$DIR_NAME || exit 1

    function dotfiles {
    /usr/bin/git --git-dir=$HOME/$DIR_NAME --work-tree=$HOME $@
    }
    dotfiles checkout
    if [ $? -ne 0 ]; then
        # if checkout fails, remove all files
        printf "Checkout failed: removing conflicting files\n"
        cd $HOME
        dotfiles checkout 2>&1 | egrep "\s+\." | awk '{$1=$1;print}' | xargs -d '\n' rm -rf
        dotfiles checkout || exit 1
    fi;

    dotfiles config status.showUntrackedFiles no
    # printf "alias dots='git --git-dir=$HOME/$DIR_NAME/ --work-tree=$HOME'\n" >> $HOME/.bashrc
    printf "\nConfiguration files applied successfully\n"

    # Install themes
    git clone https://github.com/jurc192/themes.git $HOME/.themes || exit 1
HEREDOC


# Enable services
systemctl enable NetworkManager


printf "\nInstallation completed!\n"