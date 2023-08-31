#!/bin/bash -eux

# Enable color support user profile template file.
sed --in-place "s/#alias dir='dir --color=auto'/alias dir='dir --color=auto'/g" /etc/skel/.bashrc
sed --in-place "s/#alias vdir='vdir --color=auto'/alias vdir='vdir --color=auto'/g" /etc/skel/.bashrc
sed --in-place "s/#alias grep='grep --color=auto'/alias grep='grep --color=auto'/g" /etc/skel/.bashrc
sed --in-place "s/#alias fgrep='fgrep --color=auto'/alias fgrep='fgrep --color=auto'/g" /etc/skel/.bashrc
sed --in-place "s/#alias egrep='egrep --color=auto'/alias egrep='egrep --color=auto'/g" /etc/skel/.bashrc
sed --in-place "s/#export GCC_COLORS='error=01;31:warning=01;35:note=01;36:caret=01;32:locus=01:quote=01'/export GCC_COLORS='error=01;31:warning=01;35:note=01;36:caret=01;32:locus=01:quote=01'/g" /etc/skel/.bashrc

# Enable color terminal support for root.
cat <<-EOF >> /root/.bashrc
# set a fancy prompt (non-color, unless we know we "want" color)
case "\$TERM" in
    xterm-color|*-256color) color_prompt=yes;;
esac

# comment for a colored prompt, if the terminal has the capability; turned
# off by default to not distract the user: the focus in a terminal window
# should be on the output of commands, not on the prompt
force_color_prompt=yes

if [ -n "\$force_color_prompt" ]; then
    if [ -x /usr/bin/tput ] && tput setaf 1 >&/dev/null; then
        # We have color support; assume it's compliant with Ecma-48
        # (ISO/IEC-6429). (Lack of such support is extremely rare, and such
        # a case would tend to support setf rather than setaf.)
        color_prompt=yes
    else
        color_prompt=
    fi
fi

if [ "\$color_prompt" = yes ]; then
    PS1='\${debian_chroot:+(\$debian_chroot)}\[\033[01;32m\]\u@\h\[\033[00m\]:\[\033[01;34m\]\w\[\033[00m\]\\$ '
else
    PS1='\${debian_chroot:+(\$debian_chroot)}\u@\h:\w\\$ '
fi
unset color_prompt force_color_prompt


# If this is an xterm set the title to user@host:dir
case "\$TERM" in
xterm*|rxvt*)
    PS1="\[\e]0;\${debian_chroot:+(\$debian_chroot)}\u@\h: \w\a\]\$PS1"
    ;;
*)
    ;;
esac

# enable color support of ls and also add handy aliases
if [ -x /usr/bin/dircolors ]; then
    test -r ~/.dircolors && eval "\$(dircolors -b ~/.dircolors)" || eval "\$(dircolors -b)"
    alias ls='ls --color=auto'
    alias dir='dir --color=auto'
    alias vdir='vdir --color=auto'

    alias grep='grep --color=auto'
    alias fgrep='fgrep --color=auto'
    alias egrep='egrep --color=auto'
fi

# colored GCC warnings and errors
export GCC_COLORS='error=01;31:warning=01;35:note=01;36:caret=01;32:locus=01:quote=01'

EOF

cat <<-EOF > /root/.vimrc
set mouse-=a
EOF

# If the vagrant user is already setup, edit the existing bashrc file.
if [ -d /home/vagrant/ ] && [ -f /home/vagrant/.bashrc ]; then
  sed --in-place "s/#alias dir='dir --color=auto'/alias dir='dir --color=auto'/g" /home/vagrant/.bashrc
  sed --in-place "s/#alias vdir='vdir --color=auto'/alias vdir='vdir --color=auto'/g" /home/vagrant/.bashrc
  sed --in-place "s/#alias grep='grep --color=auto'/alias grep='grep --color=auto'/g" /home/vagrant/.bashrc
  sed --in-place "s/#alias fgrep='fgrep --color=auto'/alias fgrep='fgrep --color=auto'/g" /home/vagrant/.bashrc
  sed --in-place "s/#alias egrep='egrep --color=auto'/alias egrep='egrep --color=auto'/g" /home/vagrant/.bashrc
  sed --in-place "s/#export GCC_COLORS='error=01;31:warning=01;35:note=01;36:caret=01;32:locus=01:quote=01'/export GCC_COLORS='error=01;31:warning=01;35:note=01;36:caret=01;32:locus=01:quote=01'/g" /home/vagrant/.bashrc
  chown vagrant:vagrant /home/vagrant/.bashrc
fi

if [ -d /home/vagrant/ ]; then
cat <<-EOF > /home/vagrant/.vimrc
set mouse-=a
EOF
chown vagrant:vagrant /home/vagrant/.vimrc
fi
