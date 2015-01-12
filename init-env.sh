#!/bin/bash

PREFIX=~/.local

function to-dir() {
    mkdir -p "${1}"
    cd "${1}"
}

function init-git() {
    if [ ! -d .git ]; then
        git init
        git remote add origin "https://github.com/moonlite/${1}.git"
    fi
    git pull origin master
    if [ -f .gitmodules ]; then
        git submodule update --init --remote
    fi
}

function init-dir () {
    to-dir "${HOME}/${1}"
    init-git "${1}"
    cd "${HOME}"
}

function setup-link() {
    if [ -h "${2}" ]; then
	rm "${2}"
    elif [ -e "${2}" ]; then
        mv "${2}" "${2}.bak.$(date -Is)"
    fi

    echo -e "${1}\t ⇒ ${2}"
    ln -s "${1}" "${2}"
}

function setup-bin() {
    local bin;
    local target;

    if [ -z "${2}" ]; then
	bin=`basename "${1}"`
    else
	bin="${2}"
    fi
    target="${HOME}/.local/bin/$bin"

    setup-link "${1}" "${target}"
    chmod +x "${target}"
}


#############

function setup-emacs() {
    if [ -d "${HOME}/.emacs.d/" ]; then
        echo "Emacs already set up..."
    else
        echo "Setting up Emacs..."
        rm ~/.emacs 2> /dev/null
        init-dir ".emacs.d"
        setup-bin "${HOME}/.emacs.d/lisp/cask/bin/cask"
        ( cd .emacs.d && cask install )
    fi
}

function setup-config() {
    echo "Setting up configs..."
    init-dir ".config"

    setup-link "${HOME}/.config/bash/rc"      "${HOME}/.bashrc"
    setup-link "${HOME}/.config/bash/profile" "${HOME}/.bash_profile"
    setup-link "${HOME}/.config/bash/logout"  "${HOME}/.bash_logout"

    source ~/.bashrc
}

function setup-jhbuild() {
    if [ `command -v jhbuild` ]; then
        echo "JHBuild already found..."
    else
        echo "Setting up JHBuild..."
        to-dir "${HOME}/Code/jhbuild"
        git clone https://git.gnome.org/browse/jhbuild . || git pull
        ./autogen.sh --prefix="$PREFIX/" && make && make install
        echo
        echo "Installing JHBuild sysdeps..."
        jhbuild sysdeps --install
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
    if [ -f /etc/yum.repos.d/rpmfusion-free.repo ] && [ -f /etc/yum.repos.d/rpmfusion-nonfree.repo ]; then
        echo "RPM Fusion already set up..."
    else
        echo "Setting up RPM Fusion..."
        sudo su -c 'yum localinstall --nogpgcheck http://download1.rpmfusion.org/free/fedora/rpmfusion-free-release-$(rpm -E %fedora).noarch.rpm http://download1.rpmfusion.org/nonfree/fedora/rpmfusion-nonfree-release-$(rpm -E %fedora).noarch.rpm'
    fi
}

function install-packages() {
    echo "Installing packages..."
    PACKAGES="                          \
        bijiben                         \
        cabal-install                   \
        california                      \
        clang-devel                     \
        cmake                           \
        corebird                        \
        docbook-dtds                    \
        docbook-style-xsl               \
        emacs                           \
        epiphany                        \
        fedup                           \
        gimp                            \
        git                             \
        git-bz                          \
        gitflow                         \
        gitg                            \
        global                          \
        gnome-common                    \
        gnome-maps                      \
        gnome-tweak-tool                \
        golang                          \
        golang-godoc                    \
        gstreamer1-libav                \
        gstreamer1-plugins-bad          \
        gstreamer1-plugins-bad-freeworld\
        gstreamer1-plugins-ugly         \
        intltool                        \
        llvm-devel                      \
        llvm-static                     \
        meld                            \
        mercurial                       \
        npm                             \
        pandoc                          \
        python-pip                      \
        screen                          \
        tig                             \
        tmux                            \
        yelp-tools                      \
    "
    sudo su -c "echo $PACKAGES | xargs yum install -y"
}

function install-npm-packages() {
    echo "Installing NPM packages..."
    npm install -g grunt-cli jshint jscs jake http-server editorconfig 2> /dev/null
}

function install-python-packages() {
    echo "Installing Python packages..."
    pip install --user git-spindle
}

function install-go-packages() {
    echo "Installing go packages..."
    go get github.com/nsf/gocode
    go get github.com/dougm/goflymake
    go get code.google.com/p/rog-go/exp/cmd/godef
    go get github.com/monochromegane/the_platinum_searcher/...
}

function install-chrome() {
    if [ `command -v google-chrome` ]; then
        echo "Google Chrome already installed..."
    else
        echo "Installing Google Chrome..."
        sudo su -c 'yum localinstall --nogpgcheck https://dl.google.com/linux/direct/google-chrome-stable_current_x86_64.rpm'
    fi
}

function install-spotify() {
    if [ `command -v spotify` ]; then
        echo "Spotify already installed..."
    else
        echo "Installing Spotify..."
        to-dir "${HOME}/Code/spotify-make"
        if [ ! -d .git ]; then
            git clone https://github.com/leamas/spotify-make.git .
        else
            git pull
        fi
        ./configure --prefix="${PREFIX}/"
        make download
        make install
        make register
    fi
}

function install-rtags() {
    if [ `command -v rdm` ]; then
        echo "RTags already installed..."
    else
        echo "Building RTags..."
        if [ -d "${HOME}/Code/rtags" ]; then
            echo "RTags clone already exists. Aborting."
        else
            to-dir "${HOME}/Code/rtags"
            git clone --depth 1 https://github.com/Andersbakken/rtags.git .
            git submodule update  --init
            to-dir "${HOME}/Code/rtags/build"
            cmake -DCMAKE_INSTALL_PREFIX:PATH="${PREFIX}/" .. && \
                make                                          && \
                make install
            cd "${HOME}"
            if [ ! -x "${HOME}/.local/bin/gcc-rtags-wrapper.sh" ]; then
                echo "Installing GCC wrapper symlinks..."
                install -m 755 "${HOME}/Code/rtags/bin/gcc-rtags-wrapper.sh" ~/.local/bin/
                for COMP in `echo -e "gcc\nc++\ncc\ng++"`; do
                    setup-bin "${HOME}/.local/bin/gcc-rtags-wrapper.sh" "$COMP";
                done
            fi
        fi
    fi
}

setup-rpmfusion
echo
install-packages
echo
setup-config
echo
setup-emacs
echo
install-go-packages
echo
install-npm-packages
echo
install-python-packages
echo
setup-jhbuild
echo
install-chrome
echo
install-spotify
echo
install-rtags
echo
echo "Done!"
