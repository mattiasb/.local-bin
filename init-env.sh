#!/bin/bash

function to-dir() {
    mkdir -p "${1}"
    cd "${1}"
}

function init-git() {
    if [ ! -d .git ]; then
	git init
	git remote add origin "https://github.com/moonlite/${1}.git"
	git fetch
	git checkout master
    fi
}

function init-dir () {
    to-dir "${HOME}/${1}"

    init-git "${1}"
    git pull
    cd "${HOME}"
}

function setup-link() {
    if [ ! -h "${2}" ]; then
	mv "${2}" "${2}.bak"
	ln -s "${1}" "${2}"
    fi
}

#############

function setup-emacs() {
    echo "Setting up emacs..."
    init-dir ".emacs.d"
}

function setup-config() {
    echo "Setting up configs..."
    init-dir ".config"

    setup-link "${HOME}/.config/npm/config"   "${HOME}/.npmrc"
    setup-link "${HOME}/.config/bash/rc"      "${HOME}/.bashrc"
    setup-link "${HOME}/.config/bash/profile" "${HOME}/.bash_profile"
    setup-link "${HOME}/.config/bash/logout"  "${HOME}/.bash_logout"
    setup-link "${HOME}/.config/git/config"   "${HOME}/.gitconfig"

    source ~/.bashrc
}

function setup-jhbuild() {
    if [ ! -x "${HOME}/.local/bin/jhbuild" ]; then
        echo "Setting up JHBuild..."
        to-dir "${HOME}/Code/jhbuild"
        git clone https://git.gnome.org/browse/jhbuild . || git pull
        ./autogen.sh --prefix="${HOME}/.local/" && make && make install
        echo
        echo "Installing JHBuild sysdeps..."
        jhbuild sysdeps --install
    else
        echo "JHBuild already found..."
    fi

    if [ ! -d /opt/gnome ]; then
        echo
        echo "Setting up install dir [/opt/gnome]..."
        sudo mkdir -m 0775 -p /opt/gnome
        sudo chown root:wheel /opt/gnome
    fi

    if [ ! -d "${HOME}/Code/gnome" ]; then
        echo
        echo "Setting up checkout dir [${HOME}/Code/gnome]..."
        mkdir -p "${HOME}/Code/gnome"
    fi

    echo "JHBuild setup done..."
    cd "${HOME}"
}

function setup-rpmfusion() {
    echo "Setting up RPM Fusion..."
    sudo su -c 'yum localinstall --nogpgcheck http://download1.rpmfusion.org/free/fedora/rpmfusion-free-release-$(rpm -E %fedora).noarch.rpm http://download1.rpmfusion.org/nonfree/fedora/rpmfusion-nonfree-release-$(rpm -E %fedora).noarch.rpm'
}

function install-packages() {
    echo "Installing packages..."
    pkcon install -y 					\
        git git-bz emacs npm meld corebird 		\
	cabal-install gnome-tweak-tool 			\
	gnome-maps epiphany gnome-common yelp-tools 	\
	intltool screen docbook-dtds docbook-style-xsl
}

function install-npm-packages() {
    echo "Installing NPM packages..."
    npm install -g grunt-cli jshint jake http-server editorconfig
}

# function install-spotify() {
#     to-dir "${HOME}/Downloads/spotify-make"
#     git clone https://github.com/leamas/spotify-make.git .
#     ./configure --user
#     make download
#     make install
#     make register
# }

function install-chrome() {
    echo "Installing Google Chrome..."
    sudo su -c 'yum localinstall --nogpgcheck https://dl.google.com/linux/direct/google-chrome-stable_current_x86_64.rpm'
}

setup-rpmfusion
echo
install-packages
echo
setup-config
echo
setup-emacs
echo
install-npm-packages
echo
setup-jhbuild
echo
install-chrome
echo
echo "Done!"
