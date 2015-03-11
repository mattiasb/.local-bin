#!/bin/bash

PREFIX=~/.local

GH_USERNAME=moonlite

function mkcd() {
    if [ ! -e "${1}" ]; then
        mkdir -p "${1}"
    fi
    cd "${1}"
}

function git-clone {
    local url="${1}"
    local dir="${2}"

    if [ -z "${dir}" ]; then
        dir="${HOME}/Code/Other/${repo}/"
    fi

    mkcd "${dir}"

    if [ ! -d .git ]; then
        git clone "${url}" .
    else
        git pull origin master
    fi

    if [ -f .gitmodules ]; then
        git submodule update --init --remote
    fi
}

function gh-clone() {
    local org="${1}"
    local repo="${2}"
    local dir="${3}"
    local url="https://github.com/${org}/${repo}.git"

    if [ -z "${dir}" ]; then
        dir="${HOME}/Code/${org}/${repo}/"
    fi

    git-clone "${url}" "${dir}"
}

function clone-config-dir () {
    gh-clone "${GH_USERNAME}" "${1}" "${HOME}/${1}"
}

function safe-link() {
    if [ -h "${2}" ]; then
	rm "${2}"
    elif [ -e "${2}" ]; then
        mv "${2}" "${2}.bak.$(date -Is)"
    fi

    echo -e "${1}\t ⇒ ${2}"
    ln -s "${1}" "${2}"
}

function safe-link-bin() {
    local bin;
    local target;

    if [ -z "${2}" ]; then
	bin=`basename "${1}"`
    else
	bin="${2}"
    fi
    target="${HOME}/.local/bin/$bin"

    safe-link "${1}" "${target}"
    chmod +x "${target}"
}


#############

function setup-emacs() {
    if [ ! -d "${HOME}/.emacs.d/" ]; then
        echo "Initializing Emacs..."
        rm ~/.emacs 2> /dev/null
        clone-config-dir ".emacs.d"
        safe-link-bin "${HOME}/.emacs.d/lisp/cask/bin/cask"
    fi

    echo "Updating Emacs..."
    cd "${HOME}/.emacs.d/"
    cask update
    yasel licenses/ snippets/
}

function setup-config() {
    echo "Setting up configs..."
    clone-config-dir ".config"

    safe-link "${HOME}/.config/bash/rc"      "${HOME}/.bashrc"
    safe-link "${HOME}/.config/bash/profile" "${HOME}/.bash_profile"
    safe-link "${HOME}/.config/bash/logout"  "${HOME}/.bash_logout"

    source ~/.bashrc
}

function setup-jhbuild() {
    if [ `command -v jhbuild` ]; then
        echo "JHBuild already installed..."
    else
        echo "Setting up JHBuild..."
        git-clone https://git.gnome.org/browse/jhbuild "${HOME}/Code/gnome/jhbuild"
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
        gnome-calendar                  \
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
        nuntius                         \
        pandoc                          \
        python-pip                      \
        tig                             \
        tmux                            \
        yelp-tools                      \
    "
    sudo su -c "echo $PACKAGES | xargs yum install -y"
}

function install-npm-packages() {
    echo "Installing NPM packages..."
    npm install -g                      \
        grunt-cli                       \
        jshint                          \
        jscs                            \
        jake                            \
        http-server                     \
        editorconfig                    \
        yasel                           \
        2> /dev/null
}

function install-python-packages() {
    echo "Installing/upgrading Python packages..."
    pip install --upgrade --user git-spindle
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

        gh-clone "leamas" "spotify-make"
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
        gh-clone "Andersbakken" "rtags"
        mkcd build
        cmake -DCMAKE_INSTALL_PREFIX:PATH="${PREFIX}/" .. && \
            make                                          && \
            make install
        cd "${HOME}"
        if [ ! -x "${HOME}/.local/bin/gcc-rtags-wrapper.sh" ]; then
            echo "Installing GCC wrapper symlinks..."
            install -m 755 "${HOME}/Code/github/rtags/bin/gcc-rtags-wrapper.sh" ~/.local/bin/
            for COMP in `echo -e "gcc\nc++\ncc\ng++"`; do
                safe-link-bin "${HOME}/.local/bin/gcc-rtags-wrapper.sh" "$COMP";
            done
        fi
    fi
}

setup-rpmfusion
echo
install-packages
echo
setup-config
echo
install-npm-packages
echo
setup-emacs
echo
install-go-packages
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
