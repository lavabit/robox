#!/bin/sh -eux

retry() {
  local COUNT=1
  local RESULT=0
  while [[ "${COUNT}" -le 10 ]]; do
    [[ "${RESULT}" -ne 0 ]] && {
      [ "`which tput 2> /dev/null`" != "" ] && tput setaf 1
      echo -e "\\n${*} failed... retrying ${COUNT} of 10.\\n" >&2
      [ "`which tput 2> /dev/null`" != "" ] && tput sgr0
    }
    "${@}" && { RESULT=0 && break; } || RESULT="${?}"
    COUNT="$((COUNT + 1))"

    # Increase the delay with each iteration.
    DELAY="$((DELAY + 10))"
    sleep $DELAY
  done

  [[ "${COUNT}" -gt 10 ]] && {
    [ "`which tput 2> /dev/null`" != "" ] && tput setaf 1
    echo -e "\\nThe command failed 10 times.\\n" >&2
    [ "`which tput 2> /dev/null`" != "" ] && tput sgr0
  }

  return "${RESULT}"
}

# Configure the main repository mirrors.
printf "https://sjc.edge.kernel.org/alpine/v3.8/main\n" > /etc/apk/repositories
printf "https://sjc.edge.kernel.org/alpine/v3.8/community\n" >> /etc/apk/repositories

# Update the package list and then upgrade.
retry apk update --no-cache
retry apk upgrade

# Install various basic system utilities.
retry apk add vim man man-pages bash gawk wget curl sudo lsof file grep readline mdocml sysstat lm_sensors findutils sysfsutils dmidecode libmagic sqlite-libs ca-certificates ncurses-libs ncurses-terminfo ncurses-terminfo-base psmisc

# Setup vim as the default editor.
printf "alias vi=vim\n" >> /etc/profile.d/vim.sh

# Make the shell bash, instead of ash.
sed -i -e "s/\/bin\/ash/\/bin\/bash/g" /etc/passwd

# Run the updatedb script so the locate command works.
updatedb

# Reboot onto the new kernel (if applicable).
reboot
