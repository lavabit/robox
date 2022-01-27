#!/bin/bash

# Setup OpenJDK 1.8 as the default, which is required for the branches between 14.1 
# and 15.1. Newer releases use the JDK release bundled with the source code. 
#  LineageOS 18.0-18.1: OpenJDK 11 (bundled with source download)
#  LineageOS 16.0-17.1: OpenJDK 1.9 (bundled with source download)
#  LineageOS 14.1-15.1: OpenJDK 1.8 (use openjdk-8-jdk)
#  LineageOS 11.0-13.0: OpenJDK 1.7 (use openjdk-7-jdk)

retry() {
  local COUNT=1
  local RESULT=0
  while [[ "${COUNT}" -le 10 ]]; do
    [[ "${RESULT}" -ne 0 ]] && {
      [ "`which tput 2> /dev/null`" != "" ] && tput setaf 1
      echo -e "\n${*} failed... retrying ${COUNT} of 10.\n" >&2
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
    echo -e "\nThe command failed 10 times.\n" >&2
    [ "`which tput 2> /dev/null`" != "" ] && tput sgr0
  }

  return "${RESULT}"
}

# Disable IPv6 or DNS names will resolve to AAAA yet connections will fail.
sysctl net.ipv6.conf.all.disable_ipv6=1

# To allow for automated installs, we disable interactive configuration steps.
export DEBIAN_FRONTEND=noninteractive
export DEBCONF_NONINTERACTIVE_SEEN=true

# Ensure Python 3.6 is installed. The ppa dropped support for Xenial, so we have
# to download the deb files from the build system. 

retry curl --location --output "python3.6_3.6.13-1+xenial2_amd64.deb" "https://launchpad.net/~deadsnakes/+archive/ubuntu/ppa/+build/21060900/+files/python3.6_3.6.13-1+xenial2_amd64.deb"
retry curl --location --output "python3.6-minimal_3.6.13-1+xenial2_amd64.deb" "https://launchpad.net/~deadsnakes/+archive/ubuntu/ppa/+build/21060900/+files/python3.6-minimal_3.6.13-1+xenial2_amd64.deb"
retry curl --location --output "libpython3.6-stdlib_3.6.13-1+xenial2_amd64.deb" "https://launchpad.net/~deadsnakes/+archive/ubuntu/ppa/+build/21060900/+files/libpython3.6-stdlib_3.6.13-1+xenial2_amd64.deb"
retry curl --location --output "libpython3.6-minimal_3.6.13-1+xenial2_amd64.deb" "https://launchpad.net/~deadsnakes/+archive/ubuntu/ppa/+build/21060900/+files/libpython3.6-minimal_3.6.13-1+xenial2_amd64.deb"

echo "16055c7d458f61ed7cd52276073bf40a6319c4c36143f328d382f630eccfd756  python3.6_3.6.13-1+xenial2_amd64.deb" | sha256sum -c || exit 1
echo "0226db72e2e2b6db09c0f69eeff496fb034b9a47ebb66b4c1f0f14f73749c711  python3.6-minimal_3.6.13-1+xenial2_amd64.deb" | sha256sum -c || exit 1
echo "2a58467b2fdfe9efe1a4cdfb62684606495061b2c08a6b20605d77458ea1e8fa  libpython3.6-stdlib_3.6.13-1+xenial2_amd64.deb" | sha256sum -c || exit 1
echo "0430bc1033484052e20798d8caa73823fa5f99b214e2fba9634fe3fda5c82ae4  libpython3.6-minimal_3.6.13-1+xenial2_amd64.deb" | sha256sum -c || exit 1

# Install via dpkg.
dpkg -i "python3.6_3.6.13-1+xenial2_amd64.deb" "python3.6-minimal_3.6.13-1+xenial2_amd64.deb" "libpython3.6-stdlib_3.6.13-1+xenial2_amd64.deb" "libpython3.6-minimal_3.6.13-1+xenial2_amd64.deb"

# Assuming the Python 3.6 has dependencies... install them here.
retry apt --assume-yes install -f

# Delete the downloaded Python 3.6 packages.
rm --force "python3.6_3.6.13-1+xenial2_amd64.deb" "python3.6-minimal_3.6.13-1+xenial2_amd64.deb" "libpython3.6-stdlib_3.6.13-1+xenial2_amd64.deb" "libpython3.6-minimal_3.6.13-1+xenial2_amd64.deb"

# The old method for install Python 3.6 using the PPA repo.
# add-apt-repository --yes ppa:deadsnakes/ppa
# retry apt-get --assume-yes update
# retry apt-get --assume-yes install python3.6

# Use an alias to force the use of Python 3.6 over Python 3.5.
printf "\nalias python='/usr/bin/python3.6'\n" >> /home/vagrant/.bashrc
printf "\nalias python='/usr/bin/python3.6'\n" >> /home/vagrant/.bash_aliases

# Install developer tools.
retry apt-get --assume-yes install vim vim-nox wget curl gnupg mlocate sysstat lsof pciutils usbutils vnstat apt-file

retry apt-get --assume-yes install abootimg bc bison build-essential curl flex g++-multilib gcc-multilib git gnupg gperf pigz pbzip2 liblz4-tool imagemagick lib32ncurses5-dev lib32readline6-dev lib32z1-dev libesd0-dev liblz4-tool libncurses5-dev libsdl1.2-dev libssl-dev libwxgtk3.0-dev libxml2 libxml2-utils lzop pngcrush rsync schedtool squashfs-tools xsltproc zip zlib1g-dev ninja-build ccache unzip

# Java 8 Support
retry apt-get --assume-yes install openjdk-8-jdk openjdk-8-jdk-headless openjdk-8-jre openjdk-8-jre-headless icedtea-8-plugin

# Java dependencies
retry apt-get --assume-yes install maven libatk-wrapper-java libatk-wrapper-java-jni libpng16-16 libsctp1 libgif7

# Download the OpenJDK 1.7 packages.
retry curl --location --output openjdk-7-jre_7u181-2.6.14-1~deb8u1_amd64.deb http://archive.debian.org/debian/pool/main/o/openjdk-7/openjdk-7-jre_7u181-2.6.14-1~deb8u1_amd64.deb
retry curl --location --output openjdk-7-jre-headless_7u181-2.6.14-1~deb8u1_amd64.deb http://archive.debian.org/debian/pool/main/o/openjdk-7/openjdk-7-jre-headless_7u181-2.6.14-1~deb8u1_amd64.deb
retry curl --location --output openjdk-7-jdk_7u181-2.6.14-1~deb8u1_amd64.deb http://archive.debian.org/debian/pool/main/o/openjdk-7/openjdk-7-jdk_7u181-2.6.14-1~deb8u1_amd64.deb
retry curl --location --output libjpeg62-turbo_1.5.1-2_amd64.deb https://mirrors.kernel.org/debian/pool/main/libj/libjpeg-turbo/libjpeg62-turbo_1.5.1-2_amd64.deb

echo "55b4208bca9e772cd3d6e6a3f6bf3949d170e6da77e53b0ba59abb8f1658bb64  libjpeg62-turbo_1.5.1-2_amd64.deb" | sha256sum -c || exit 1
echo "a7fa42ebfd7c12bb9de88ead6e40246e92f0437215049efa359678b07b5a513f  openjdk-7-jdk_7u181-2.6.14-1~deb8u1_amd64.deb" | sha256sum -c || exit 1
echo "4635c358809ad2d4fc5ea965779272779a3296a10400c52130dd2b6830408ac1  openjdk-7-jre-headless_7u181-2.6.14-1~deb8u1_amd64.deb" | sha256sum -c || exit 1
echo "f6ce7005eb6a4a847c63251a6ad653c58fff0766db4f38f3f13b8a053e069207  openjdk-7-jre_7u181-2.6.14-1~deb8u1_amd64.deb" | sha256sum -c || exit 1

# Install via dpkg.
dpkg -i openjdk-7-jre_7u181-2.6.14-1~deb8u1_amd64.deb openjdk-7-jre-headless_7u181-2.6.14-1~deb8u1_amd64.deb openjdk-7-jdk_7u181-2.6.14-1~deb8u1_amd64.deb libjpeg62-turbo_1.5.1-2_amd64.deb

# Assuming the OpenJDK has dependencies... install them here.
retry apt --assume-yes install -f

update-java-alternatives -s java-1.8.0-openjdk-amd64

# Delete the downloaded Java 7 packages.
rm --force openjdk-7-jre_7u181-2.6.14-1~deb8u1_amd64.deb openjdk-7-jre-headless_7u181-2.6.14-1~deb8u1_amd64.deb openjdk-7-jdk_7u181-2.6.14-1~deb8u1_amd64.deb libjpeg62-turbo_1.5.1-2_amd64.deb

# Reenable TLSv1 support for Java 8, since it is required for old versions of Jack.
sed -i '/^jdk.tls.disabledAlgorithms=/s/TLSv1, TLSv1.1, //' /etc/java-8-openjdk/security/java.security

# Download the Android tools.
retry curl  --location --output platform-tools-latest-linux.zip https://dl.google.com/android/repository/platform-tools-latest-linux.zip

# Install the platform tools.
unzip platform-tools-latest-linux.zip -d /usr/local/

# Delete the downloaded tools archive.
rm --force platform-tools-latest-linux.zip

# Ensure the platform tools are in the binary search path.
printf "PATH=/usr/local/platform-tools/:$PATH\n" > /etc/profile.d/platform-tools.sh

# Install the repo utility.
retry curl  --location https://storage.googleapis.com/git-repo-downloads/repo > /usr/bin/repo
chmod a+x /usr/bin/repo

# Setup higher resource limits.
printf "*    soft    nofile    8192\n" >> /etc/security/limits.d/60-lineage.conf
printf "*    hard    nofile    8192\n" >> /etc/security/limits.d/60-lineage.conf
printf "*    soft    stack     65536\n" >> /etc/security/limits.d/60-lineage.conf
printf "*    hard    stack     65536\n" >> /etc/security/limits.d/60-lineage.conf

# Setup the android udev rules.
cat <<-EOF | base64 --decode > /etc/udev/rules.d/51-android.rules
IyBUaGVzZSBydWxlcyByZWZlcjogaHR0cHM6Ly9kZXZlbG9wZXIuYW5kcm9pZC5jb20vc3R1ZGlv
L3J1bi9kZXZpY2UuaHRtbAojIGFuZCBpbmNsdWRlIG1hbnkgc3VnZ2VzdGlvbnMgZnJvbSBBcmNo
IExpbnV4LCBHaXRIdWIgYW5kIG90aGVyIENvbW11bml0aWVzLgojIExhdGVzdCB2ZXJzaW9uIGNh
biBiZSBmb3VuZCBhdDogaHR0cHM6Ly9naXRodWIuY29tL00wUmYzMC9hbmRyb2lkLXVkZXYtcnVs
ZXMKCiMgU2tpcCB0aGlzIHNlY3Rpb24gYmVsb3cgaWYgdGhpcyBkZXZpY2UgaXMgbm90IGNvbm5l
Y3RlZCBieSBVU0IKU1VCU1lTVEVNIT0idXNiIiwgR09UTz0iYW5kcm9pZF91c2JfcnVsZXNfZW5k
IgoKTEFCRUw9ImFuZHJvaWRfdXNiX3J1bGVzX2JlZ2luIgojIERldmljZXMgbGlzdGVkIGhlcmUg
aW4gYW5kcm9pZF91c2JfcnVsZXNfe2JlZ2luLi4uZW5kfSBhcmUgY29ubmVjdGVkIGJ5IFVTQgoj
CUFjZXIKQVRUUntpZFZlbmRvcn0hPSIwNTAyIiwgR09UTz0ibm90X0FjZXIiCkVOVnthZGJfdXNl
cn09InllcyIKIwkJSWNvbmlhIFRhYiBBMS04MzAKQVRUUntpZFByb2R1Y3R9PT0iMzYwNCIsIEVO
VnthZGJfYWRiZmFzdH09InllcyIKIwkJSWNvbmlhIFRhYiBBNTAwCkFUVFJ7aWRQcm9kdWN0fT09
IjMzMjUiLCBFTlZ7YWRiX2FkYmZhc3R9PSJ5ZXMiCiMJCUxpcXVpZCAoMzIwMj1ub3JtYWwsMzIw
Mz1kZWJ1ZykKQVRUUntpZFByb2R1Y3R9PT0iMzIwMyIsIFNZTUxJTksrPSJhbmRyb2lkX2FkYiIK
R09UTz0iYW5kcm9pZF91c2JfcnVsZV9tYXRjaCIKTEFCRUw9Im5vdF9BY2VyIgoKIwlBY3Rpb25z
IFNlbWljb25kdWN0b3IgQ28uLCBMdGQKQVRUUntpZFZlbmRvcn09PSIxMGQ2IiwgRU5We2FkYl91
c2VyfT0ieWVzIgojCQlEZW52ZXIgVEFEIDcwMTExCkFUVFJ7aWRQcm9kdWN0fT09IjBjMDIiLCBT
WU1MSU5LKz0iYW5kcm9pZF9hZGIiCgojCUFEVkFOQ0UKQVRUUntpZFZlbmRvcn09PSIwYTVjIiwg
RU5We2FkYl91c2VyfT0ieWVzIgojCQlTNQpBVFRSe2lkUHJvZHVjdH09PSJlNjgxIiwgU1lNTElO
Sys9ImFuZHJvaWRfYWRiIgoKIwlBbWF6b24gTGFiMTI2CkFUVFJ7aWRWZW5kb3J9PT0iMTk0OSIs
IEVOVnthZGJfdXNlcn09InllcyIKIwkJQW1hem9uIEtpbmRsZSBGaXJlCkFUVFJ7aWRQcm9kdWN0
fT09IjAwMDYiLCBFTlZ7YWRiX2FkYmZhc3R9PSJ5ZXMiCgojCUFyY2hvcwpBVFRSe2lkVmVuZG9y
fSE9IjBlNzkiLCBHT1RPPSJub3RfQXJjaG9zIgpFTlZ7YWRiX3VzZXJ9PSJ5ZXMiCiMJCTQzCkFU
VFJ7aWRQcm9kdWN0fT09IjE0MTciLCBFTlZ7YWRiX2FkYmZhc3R9PSJ5ZXMiCiMJCTEwMQpBVFRS
e2lkUHJvZHVjdH09PSIxNDExIiwgRU5We2FkYl9hZGJmYXN0fT0ieWVzIgojCQkxMDEgeHMKQVRU
UntpZFByb2R1Y3R9PT0iMTU0OSIsIEVOVnthZGJfYWRiZmFzdH09InllcyIKR09UTz0iYW5kcm9p
ZF91c2JfcnVsZV9tYXRjaCIKTEFCRUw9Im5vdF9BcmNob3MiCgojCUFTVVNUZUsKQVRUUntpZFZl
bmRvcn0hPSIwYjA1IiwgR09UTz0ibm90X0FzdXMiCiMJCUZhbHNlIHBvc2l0aXZlIC0gYWNjZXNz
b3J5CkFUVFJ7aWRQcm9kdWN0fT09IjE/Pz8iLCBHT1RPPSJhbmRyb2lkX3VzYl9ydWxlc19lbmQi
CkVOVnthZGJfdXNlcn09InllcyIKIwkJWmVucGhvbmUgNSAoNGM5MD1ub3JtYWwsNGM5MT1kZWJ1
Zyw0ZGFmPUZhc3Rib290KQpBVFRSe2lkUHJvZHVjdH09PSI0YzkxIiwgU1lNTElOSys9ImFuZHJv
aWRfYWRiIgpBVFRSe2lkUHJvZHVjdH09PSI0ZGFmIiwgU1lNTElOSys9ImFuZHJvaWRfZmFzdGJv
b3QiCiMJCVRlZ3JhIEFQWApBVFRSe2lkUHJvZHVjdH09PSI3MDMwIgpHT1RPPSJhbmRyb2lkX3Vz
Yl9ydWxlX21hdGNoIgpMQUJFTD0ibm90X0FzdXMiCgojCUF6cGVuIE9uZGEKQVRUUntpZFZlbmRv
cn09PSIxZjNhIiwgRU5We2FkYl91c2VyfT0ieWVzIgoKIwlCUQpBVFRSe2lkVmVuZG9yfSE9IjJh
NDciLCBHT1RPPSJub3RfQlEiCkVOVnthZGJfdXNlcn09InllcyIKIwkJQXF1YXJpcyA0LjUKQVRU
UntpZFByb2R1Y3R9PT0iMGMwMiIsIEVOVnthZGJfYWRiZmFzdH09InllcyIKQVRUUntpZFByb2R1
Y3R9PT0iMjAwOCIsIEVOVnthZGJfYWRiZmFzdH09InllcyIKR09UTz0iYW5kcm9pZF91c2JfcnVs
ZV9tYXRjaCIKTEFCRUw9Im5vdF9CUSIKCiMJRGVsbApBVFRSe2lkVmVuZG9yfT09IjQxM2MiLCBF
TlZ7YWRiX3VzZXJ9PSJ5ZXMiCgojCUZhaXJwaG9uZSAyCkFUVFJ7aWRWZW5kb3J9PT0iMmFlNSIs
IEVOVnthZGJfdXNlcn09InllcyIKCiMJRm94Y29ubgpBVFRSe2lkVmVuZG9yfT09IjA0ODkiLCBF
TlZ7YWRiX3VzZXJ9PSJ5ZXMiCiMJCUNvbW10aXZhIFo3MSwgR2Vla3NwaG9uZSBPbmUKQVRUUntp
ZFZlbmRvcn09PSIwNDg5IiwgQVRUUntpZFByb2R1Y3R9PT0iYzAwMSIsIFNZTUxJTksrPSJhbmRy
b2lkX2FkYiIKCiMJRnVqaXRzdS9GdWppdHN1IFRvc2hpYmEKQVRUUntpZFZlbmRvcn09PSIwNGM1
IiwgRU5We2FkYl91c2VyfT0ieWVzIgoKIwlGdXpob3UgUm9ja2NoaXAgRWxlY3Ryb25pY3MKQVRU
UntpZFZlbmRvcn09PSIyMjA3IiwgRU5We2FkYl91c2VyfT0ieWVzIgojCQlNZWRpYWNvbSBTbWFy
dHBhZCA3MTVpCkFUVFJ7aWRWZW5kb3J9PT0iMjIwNyIsIEFUVFJ7aWRQcm9kdWN0fT09IjAwMDAi
LCBTWU1MSU5LKz0iYW5kcm9pZF9hZGIiCiMJCVViaXNsYXRlIDdDaQpBVFRSe2lkVmVuZG9yfT09
IjIyMDciLCBBVFRSe2lkUHJvZHVjdH09PSIwMDEwIiwgU1lNTElOSys9ImFuZHJvaWRfYWRiIgoK
IwlHYXJtaW4tQXN1cwpBVFRSe2lkVmVuZG9yfT09IjA5MWUiLCBFTlZ7YWRiX3VzZXJ9PSJ5ZXMi
CgojCUdvb2dsZQpBVFRSe2lkVmVuZG9yfSE9IjE4ZDEiLCBHT1RPPSJub3RfR29vZ2xlIgpFTlZ7
YWRiX3VzZXJ9PSJ5ZXMiCiMgICAgICAgICAgICAgICBOZXh1cyA2UCAoNGVlMD1mYXN0Ym9vdCkK
QVRUUntpZFByb2R1Y3R9PT0iNGVlNyIsIFNZTUxJTksrPSJhbmRyb2lkX2FkYiIKIwkJTmV4dXMg
NCwgTmV4dXMgNyAyMDEzCkFUVFJ7aWRQcm9kdWN0fT09IjRlZTIiLCBTWU1MSU5LKz0iYW5kcm9p
ZF9hZGIiCkFUVFJ7aWRQcm9kdWN0fT09IjRlZTAiLCBTWU1MSU5LKz0iYW5kcm9pZF9mYXN0Ym9v
dCIKIwkJTmV4dXMgNwpBVFRSe2lkUHJvZHVjdH09PSI0ZTQyIiwgU1lNTElOSys9ImFuZHJvaWRf
YWRiIgpBVFRSe2lkUHJvZHVjdH09PSI0ZTQwIiwgU1lNTElOSys9ImFuZHJvaWRfZmFzdGJvb3Qi
CiMJCU5leHVzIDUsIE5leHVzIDEwCkFUVFJ7aWRQcm9kdWN0fT09IjRlZTEiLCBFTlZ7YWRiX2Fk
YmZhc3R9PSJ5ZXMiCiMJCU5leHVzIFMKQVRUUntpZFByb2R1Y3R9PT0iNGUyMSIKQVRUUntpZFBy
b2R1Y3R9PT0iNGUyMiIsIFNZTUxJTksrPSJhbmRyb2lkX2FkYiIKQVRUUntpZFByb2R1Y3R9PT0i
NGUyMCIsIFNZTUxJTksrPSJhbmRyb2lkX2Zhc3Rib290IgojCQlHYWxheHkgTmV4dXMKQVRUUntp
ZFByb2R1Y3R9PT0iNGUzMCIsIEVOVnthZGJfYWRiZmFzdH09InllcyIKIwkJTmV4dXMgT25lICg0
ZTExPW5vcm1hbCw0ZTEyPWRlYnVnLDBmZmY9ZGVidWcpCkFUVFJ7aWRQcm9kdWN0fT09IjRlMTIi
LCBTWU1MSU5LKz0iYW5kcm9pZF9hZGIiCkFUVFJ7aWRQcm9kdWN0fT09IjBmZmYiLCBTWU1MSU5L
Kz0iYW5kcm9pZF9mYXN0Ym9vdCIKIwkJR2VuZXJpYyBhbmQgdW5zcGVjaWZpZWQgZGVidWcgaW50
ZXJmYWNlCkFUVFJ7aWRQcm9kdWN0fT09ImQwMGQiLCBTWU1MSU5LKz0iYW5kcm9pZF9mYXN0Ym9v
dCIKIwkJSW5jbHVkZTogU2Ftc3VuZyBHYWxheHkgTmV4dXMgKEdTTSkKQVRUUntpZFByb2R1Y3R9
PT0iNGUzMCIsIFNZTUxJTksrPSJhbmRyb2lkX2Zhc3Rib290IgojCQlSZWNvdmVyeSBhZGIgZW50
cnkgZm9yIE5leHVzIEZhbWlseSAob3JpZyBkMDAxLCBPUDMgaGFzIDE4ZDE6ZDAwMikKQVRUUntp
ZFByb2R1Y3R9PT0iZDAwPyIsIFNZTUxJTksrPSJhbmRyb2lkX2FkYiIKR09UTz0iYW5kcm9pZF91
c2JfcnVsZV9tYXRjaCIKTEFCRUw9Im5vdF9Hb29nbGUiCgojCUhhaWVyCkFUVFJ7aWRWZW5kb3J9
PT0iMjAxZSIsIEVOVnthZGJfdXNlcn09InllcyIKCiMJSGlzZW5zZQpBVFRSe2lkVmVuZG9yfT09
IjEwOWIiLCBFTlZ7YWRiX3VzZXJ9PSJ5ZXMiCgojCUhvbmV5d2VsbC9Gb3hjb25uCkFUVFJ7aWRW
ZW5kb3J9IT0iMGMyZSIsIEdPVE89Im5vdF9Ib25leXdlbGwiCkVOVnthZGJfdXNlcn09InllcyIK
IwkJRDcwZQpBVFRSe2lkUHJvZHVjdH09PSIwYmEzIiwgU1lNTElOSys9ImFuZHJvaWRfYWRiIgpH
T1RPPSJhbmRyb2lkX3VzYl9ydWxlX21hdGNoIgpMQUJFTD0ibm90X0hvbmV5d2VsbCIKCiMJSFRD
CkFUVFJ7aWRWZW5kb3J9IT0iMGJiNCIsIEdPVE89Im5vdF9IVEMiCkVOVnthZGJfdXNlcn09Inll
cyIKIwkJZmFzdGJvb3QgbW9kZSBlbmFibGVkCkFUVFJ7aWRQcm9kdWN0fT09IjBmZmYiLCBFTlZ7
YWRiX2FkYmZhc3R9PSJ5ZXMiLCBHT1RPPSJhbmRyb2lkX3VzYl9ydWxlX21hdGNoIgojCQlDaGFD
aGEKQVRUUntpZFByb2R1Y3R9PT0iMGNiMiIsIEVOVnthZGJfYWRiZmFzdH09InllcyIKIwkJRGVz
aXJlIChCcmF2bykKQVRUUntpZFByb2R1Y3R9PT0iMGM4NyIsIFNZTUxJTksrPSJhbmRyb2lkX2Fk
YiIKIwkJRGVzaXJlIEhECkFUVFJ7aWRQcm9kdWN0fT09IjBjYTIiLCBTWU1MSU5LKz0iYW5kcm9p
ZF9hZGIiCiMJCURlc2lyZSBTIChTYWdhKQpBVFRSe2lkUHJvZHVjdH09PSIwY2FiIiwgU1lNTElO
Sys9ImFuZHJvaWRfYWRiIgojCQlEZXNpcmUgWgpBVFRSe2lkUHJvZHVjdH09PSIwYzkxIiwgRU5W
e2FkYl9hZGJmYXN0fT0ieWVzIgojCQlFdm8gU2hpZnQKQVRUUntpZFByb2R1Y3R9PT0iMGNhNSIs
IFNZTUxJTksrPSJhbmRyb2lkX2FkYiIKIwkJRzEKQVRUUntpZFByb2R1Y3R9PT0iMGMwMSIsIEVO
VnthZGJfYWRiZmFzdH09InllcyIKIwkJSEQyCkFUVFJ7aWRQcm9kdWN0fT09IjBjMDIiLCBFTlZ7
YWRiX2FkYmZhc3R9PSJ5ZXMiCiMJCUhlcm8gSDIwMDAKQVRUUntpZFByb2R1Y3R9PT0iMDAwMSIs
IEVOVnthZGJfYWRiZmFzdH09InllcyIKIwkJSGVybyAoR1NNKSwgRGVzaXJlCkFUVFJ7aWRQcm9k
dWN0fT09IjBjOTkiLCBTWU1MSU5LKz0iYW5kcm9pZF9hZGIiCiMJCUhlcm8gKENETUEpCkFUVFJ7
aWRQcm9kdWN0fT09IjBjOWEiLCBTWU1MSU5LKz0iYW5kcm9pZF9hZGIiCiMJCUluY3JlZGlibGUK
QVRUUntpZFByb2R1Y3R9PT0iMGM5ZSIsIFNZTUxJTksrPSJhbmRyb2lkX2FkYiIKIwkJSW5jcmVk
aWJsZSByZXYgMDAwMgpBVFRSe2lkUHJvZHVjdH09PSIwYzhkIiwgU1lNTElOSys9ImFuZHJvaWRf
YWRiIgojCQlNeVRvdWNoIDRHCkFUVFJ7aWRQcm9kdWN0fT09IjBjOTYiLCBTWU1MSU5LKz0iYW5k
cm9pZF9hZGIiCiMJCU9uZSAobTcpICYmIE9uZSAobTgpCkFUVFJ7aWRQcm9kdWN0fT09IjBjOTMi
CiMJCVNlbnNhdGlvbgpBVFRSe2lkUHJvZHVjdH09PSIwZjg3IiwgU1lNTElOSys9ImFuZHJvaWRf
YWRiIgpBVFRSe2lkUHJvZHVjdH09PSIwZmYwIiwgU1lNTElOSys9ImFuZHJvaWRfZmFzdGJvb3Qi
CiMJCU9uZSBWCkFUVFJ7aWRQcm9kdWN0fT09IjBjZTUiLCBTWU1MSU5LKz0iYW5kcm9pZF9hZGIi
CiMJCVNsaWRlCkFUVFJ7aWRQcm9kdWN0fT09IjBlMDMiLCBTWU1MSU5LKz0iYW5kcm9pZF9hZGIi
CiMJCVRhdG9vLCBEcmVhbSwgQURQMSwgRzEsIE1hZ2ljCkFUVFJ7aWRQcm9kdWN0fT09IjBjMDEi
CkFUVFJ7aWRQcm9kdWN0fT09IjBjMDIiLCBFTlZ7YWRiX2FkYmZhc3R9PSJ5ZXMiCiMJCVZpc2lv
bgpBVFRSe2lkUHJvZHVjdH09PSIwYzkxIiwgU1lNTElOSys9ImFuZHJvaWRfYWRiIgojCQlXaWxk
ZmlyZQpBVFRSe2lkUHJvZHVjdH09PSIwYzhiIiwgRU5We2FkYl9hZGJmYXN0fT0ieWVzIgojCQlX
aWxkZmlyZSBTCkFUVFJ7aWRQcm9kdWN0fT09IjBjODYiLCBFTlZ7YWRiX2FkYmZhc3R9PSJ5ZXMi
CiMJCVpvcG8gWlA5MDAsIEZhaXJwaG9uZQpBVFRSe2lkUHJvZHVjdH09PSIwYzAzIiwgRU5We2Fk
Yl9hZGJmYXN0fT0ieWVzIgojCQlab3BvIEMyCkFUVFJ7aWRQcm9kdWN0fT09IjIwMDgiLCBTWU1M
SU5LKz0ibGlibXRwLSVrIiwgRU5We0lEX01UUF9ERVZJQ0V9PSIxIiwgRU5We0lEX01FRElBX1BM
QVlFUn09IjEiCkdPVE89ImFuZHJvaWRfdXNiX3J1bGVfbWF0Y2giCkxBQkVMPSJub3RfSFRDIgoK
IwlIdWF3ZWkKQVRUUntpZFZlbmRvcn0hPSIxMmQxIiwgR09UTz0ibm90X0h1YXdlaSIKRU5We2Fk
Yl91c2VyfT0ieWVzIgojCQlJREVPUwpBVFRSe2lkUHJvZHVjdH09PSIxMDM4IiwgRU5We2FkYl9h
ZGJmYXN0fT0ieWVzIgojCQlVODg1MCBWaXNpb24KQVRUUntpZFByb2R1Y3R9PT0iMTAyMSIsIEVO
VnthZGJfYWRiZmFzdH09InllcyIKIwkJSGlLZXkgYWRiCkFUVFJ7aWRQcm9kdWN0fT09IjEwNTci
LCBTWU1MSU5LKz0iYW5kcm9pZF9hZGIiCiMJCUhpS2V5IHVzYm5ldApBVFRSe2lkUHJvZHVjdH09
PSIxMDUwIiwgU1lNTElOSys9ImFuZHJvaWRfYWRiIgojCQlNZWRpYVBhZCBNMi1BMDFMCkFUVFJ7
aWRQcm9kdWN0fT09IjEwNTIiLCBTWU1MSU5LKz0iYW5kcm9pZF9hZGIiCiMJCUh1YXdlaSBXYXRj
aApBVFRSe2lkUHJvZHVjdH09PSIxYzJjIiwgU1lNTElOSys9ImFuZHJvaWRfYWRiIgpHT1RPPSJh
bmRyb2lkX3VzYl9ydWxlX21hdGNoIgpMQUJFTD0ibm90X0h1YXdlaSIKCiMJSW50ZWwKQVRUUntp
ZFZlbmRvcn09PSI4MDg3IiwgRU5We2FkYl91c2VyfT0ieWVzIgojCQlHZWVrc3Bob25lIFJldm9s
dXRpb24KQVRUUntpZFZlbmRvcn09PSI4MDg3IiwgQVRUUntpZFByb2R1Y3R9PT0iMGExNiIsIFNZ
TUxJTksrPSJhbmRyb2lkX2FkYiIKCiMJSVVOSQpBVFRSe2lkVmVuZG9yfSE9IjI3MWQiLCBHT1RP
PSJub3RfSVVOSSIKRU5We2FkYl91c2VyfT0ieWVzIgojCQlVMwpBVFRSe2lkUHJvZHVjdH09PSJi
ZjM5IiwgU1lNTElOSys9ImFuZHJvaWRfYWRiIgpHT1RPPSJhbmRyb2lkX3VzYl9ydWxlX21hdGNo
IgpMQUJFTD0ibm90X0lVTkkiCgojCUstVG91Y2gKQVRUUntpZFZlbmRvcn09PSIyNGUzIiwgRU5W
e2FkYl91c2VyfT0ieWVzIgoKIwlLVCBUZWNoCkFUVFJ7aWRWZW5kb3J9PT0iMjExNiIsIEVOVnth
ZGJfdXNlcn09InllcyIKCiMJS3lvY2VyYQpBVFRSe2lkVmVuZG9yfT09IjA0ODIiLCBFTlZ7YWRi
X3VzZXJ9PSJ5ZXMiCgojCUxlbm92bwpBVFRSe2lkVmVuZG9yfT09IjE3ZWYiLCBFTlZ7YWRiX3Vz
ZXJ9PSJ5ZXMiCgojCUxlVHYKQVRUUntpZFZlbmRvcn0hPSIyYjBlIiwgR09UTz0ibm90X2xldHYi
CkVOVnthZGJfdXNlcn09InllcyIKIyAgIExFWDcyMCBMZUVjbyBQcm8zIDZHQiAoNjEwYz1ub3Jt
YWwsNjEwZD1kZWJ1ZywgNjEwYj1jYW1lcmEpCkFUVFJ7aWRQcm9kdWN0fT09IjYxMGQiLCBFTlZ7
YWRiX2Zhc3Rib290fT0ieWVzIgpHT1RPPSJhbmRyb2lkX3VzYl9ydWxlX21hdGNoIgpMQUJFTD0i
bm90X2xldHYiCgojCUxHCkFUVFJ7aWRWZW5kb3J9IT0iMTAwNCIsIEdPVE89Im5vdF9MRyIKRU5W
e2FkYl91c2VyfT0ieWVzIgojCQlBbGx5LCBWb3J0ZXgsIFA1MDAsIFA1MDBoCkFUVFJ7aWRQcm9k
dWN0fT09IjYxOGYiCkFUVFJ7aWRQcm9kdWN0fT09IjYxOGUiLCBTWU1MSU5LKz0iYW5kcm9pZF9h
ZGIiCiMJCUcyIEQ4MDIKQVRUUntpZFByb2R1Y3R9PT0iNjFmMSIsIFNZTUxJTksrPSJhbmRyb2lk
X2FkYiIKIwkJRzIgRDgwMwpBVFRSe2lkUHJvZHVjdH09PSI2MThjIiwgU1lNTElOSys9ImFuZHJv
aWRfYWRiIgojCQlHMiBEODAzIHJvZ2VycwpBVFRSe2lkUHJvZHVjdH09PSI2MzFmIiwgU1lNTElO
Sys9ImFuZHJvaWRfYWRiIgojCQlHMiBtaW5pIEQ2MjByIChQVFApCkFUVFJ7aWRQcm9kdWN0fT09
IjYzMWQiLCBTWU1MSU5LKz0iYW5kcm9pZF9hZGIiCiMJCUczIEQ4NTUKQVRUUntpZFByb2R1Y3R9
PT0iNjMzZSIsIFNZTUxJTksrPSJhbmRyb2lkX2FkYiIKIwkJT3B0aW11cyBMVEUKQVRUUntpZFBy
b2R1Y3R9PT0iNjMxNSIsIFNZTUxJTksrPSJhbmRyb2lkX2FkYiIKQVRUUntpZFByb2R1Y3R9PT0i
NjFmOSIsIFNZTUxJTksrPSJsaWJtdHAtJWsiLCBFTlZ7SURfTVRQX0RFVklDRX09IjEiLCBFTlZ7
SURfTUVESUFfUExBWUVSfT0iMSIKIwkJT3B0aW11cyBPbmUKQVRUUntpZFByb2R1Y3R9PT0iNjFj
NSIsIFNZTUxJTksrPSJhbmRyb2lkX2FkYiIKIwkJU3dpZnQgR1Q1NDAKQVRUUntpZFByb2R1Y3R9
PT0iNjFiNCIsIFNZTUxJTksrPSJhbmRyb2lkX2FkYiIKIwkJUDUwMCBDTTEwCkFUVFJ7aWRQcm9k
dWN0fT09IjYxYTYiLCBTWU1MSU5LKz0iYW5kcm9pZF9hZGIiCiMJCTRYIEhEIFA4ODAKQVRUUntp
ZFByb2R1Y3R9PT0iNjFmOSIsIFNZTUxJTksrPSJhbmRyb2lkX2FkYiIKR09UTz0iYW5kcm9pZF91
c2JfcnVsZV9tYXRjaCIKTEFCRUw9Im5vdF9MRyIKCiMJTWljcm9tYXgKQVRUUntpZFZlbmRvcn0h
PSIyYTk2IiwgR09UTz0ibm90X01pY3JvbWF4IgpFTlZ7YWRiX3VzZXJ9PSJ5ZXMiCiMJCVA3MDIK
QVRUUntpZFByb2R1Y3R9PT0iMjAxZCIsIFNZTUxJTksrPSJhbmRyb2lkX2FkYiIsIFNZTUxJTksr
PSJhbmRyb2lkX2Zhc3Rib290IgpHT1RPPSJhbmRyb2lkX3VzYl9ydWxlX21hdGNoIgpMQUJFTD0i
bm90X01pY3JvbWF4IgoKIwlNb3Rvcm9sYQpBVFRSe2lkVmVuZG9yfSE9IjIyYjgiLCBHT1RPPSJu
b3RfTW90b3JvbGEiCkVOVnthZGJfdXNlcn09InllcyIKIwkJQ0xJUSBYVC9RdWVuY2gKQVRUUntp
ZFByb2R1Y3R9PT0iMmQ2NiIKIwkJRGVmeS9NQjUyNQpBVFRSe2lkUHJvZHVjdH09PSI0MjhjIgoj
CQlEcm9pZApBVFRSe2lkUHJvZHVjdH09PSI0MWRiIgojCQlYb29tIElEIDEKQVRUUntpZFByb2R1
Y3R9PT0iNzBhOCIsIEVOVnthZGJfYWRiZmFzdH09InllcyIKIwkJWG9vbSBJRCAyCkFUVFJ7aWRQ
cm9kdWN0fT09IjcwYTkiLCBFTlZ7YWRiX2FkYmZhc3R9PSJ5ZXMiCiMJCVJhenIgWFQ5MTIKQVRU
UntpZFByb2R1Y3R9PT0iNDM2MiIsIEVOVnthZGJfYWRiZmFzdH09InllcyIKIwkJTW90byBYVDEw
NTIKQVRUUntpZFByb2R1Y3R9PT0iMmU4MyIsIEVOVnthZGJfYWRiZmFzdH09InllcyIKIwkJTW90
byBFL0cKQVRUUntpZFByb2R1Y3R9PT0iMmU3NiIsIEVOVnthZGJfYWRiZmFzdH09InllcyIKIwkJ
TW90byBFL0cgKER1YWwgU0lNKQpBVFRSe2lkUHJvZHVjdH09PSIyZTgwIiwgRU5We2FkYl9hZGJm
YXN0fT0ieWVzIgojCQlNb3RvIEUvRyAoR2xvYmFsIEdTTSkKQVRUUntpZFByb2R1Y3R9PT0iMmU4
MiIsIEVOVnthZGJfYWRiZmFzdH09InllcyIKR09UTz0iYW5kcm9pZF91c2JfcnVsZV9tYXRjaCIK
TEFCRUw9Im5vdF9Nb3Rvcm9sYSIKCiMJTVRLCkFUVFJ7aWRWZW5kb3J9PT0iMGU4ZCIsIEVOVnth
ZGJfdXNlcn09InllcyIKCiMJTkVDCkFUVFJ7aWRWZW5kb3J9PT0iMDQwOSIsIEVOVnthZGJfdXNl
cn09InllcyIKCiMJTm9raWEgWApBVFRSe2lkVmVuZG9yfT09IjA0MjEiLCBFTlZ7YWRiX3VzZXJ9
PSJ5ZXMiCgojCU5vb2sKQVRUUntpZFZlbmRvcn09PSIyMDgwIiwgRU5We2FkYl91c2VyfT0ieWVz
IgoKIwlOdmlkaWEKQVRUUntpZFZlbmRvcn09PSIwOTU1IiwgRU5We2FkYl91c2VyfT0ieWVzIgoj
ICAgICAgICAgICAgICAgQXVkaSBTRElTIFJlYXIgU2VhdCBFbnRlcnRhaW5tZW50IFRhYmxldApB
VFRSe2lkUHJvZHVjdH09PSI3MDAwIiwgU1lNTElOSys9ImFuZHJvaWRfZmFzdGJvb3QiCgojCU9w
cG8KQVRUUntpZFZlbmRvcn09PSIyMmQ5IiwgRU5We2FkYl91c2VyfT0ieWVzIgojCQlGaW5kIDUK
QVRUUntpZFByb2R1Y3R9PT0iMjc2NyIsIFNZTUxJTksrPSJhbmRyb2lkX2FkYiIKQVRUUntpZFBy
b2R1Y3R9PT0iMjc2NCIsIFNZTUxJTksrPSJsaWJtdHAtJWsiLCBFTlZ7SURfTVRQX0RFVklDRX09
IjEiLCBFTlZ7SURfTUVESUFfUExBWUVSfT0iMSIKCiMJT1RHVgpBVFRSe2lkVmVuZG9yfT09IjIy
NTciLCBFTlZ7YWRiX3VzZXJ9PSJ5ZXMiCgojCVBhbnRlY2gKQVRUUntpZFZlbmRvcn09PSIxMGE5
IiwgRU5We2FkYl91c2VyfT0ieWVzIgoKIwlQZWdhdHJvbgpBVFRSe2lkVmVuZG9yfT09IjFkNGQi
LCBFTlZ7YWRiX3VzZXJ9PSJ5ZXMiCgojCVBoaWxpcHMKQVRUUntpZFZlbmRvcn09PSIwNDcxIiwg
RU5We2FkYl91c2VyfT0ieWVzIgoKIwlQTUMtU2llcnJhCkFUVFJ7aWRWZW5kb3J9PT0iMDRkYSIs
IEVOVnthZGJfdXNlcn09InllcyIKCiMJUXVhbGNvbW0KQVRUUntpZFZlbmRvcn0hPSIwNWM2Iiwg
R09UTz0ibm90X1F1YWxjb21tIgpFTlZ7YWRiX3VzZXJ9PSJ5ZXMiCiMJCUdlZWtzcGhvbmUgWmVy
bwpBVFRSe2lkUHJvZHVjdH09PSI5MDI1IiwgU1lNTElOSys9ImFuZHJvaWRfYWRiIgojCQlPbmVQ
bHVzIE9uZQpBVFRSe2lkUHJvZHVjdH09PSI2NzY/IiwgU1lNTElOSys9ImFuZHJvaWRfYWRiIgoj
CQlPbmVQbHVzIFR3bwpBVFRSe2lkUHJvZHVjdH09PSI5MDExIiwgU1lNTElOSys9ImFuZHJvaWRf
YWRiIgojCQlPbmVQbHVzIDMKQVRUUntpZFByb2R1Y3R9PT0iOTAwZSIsIFNZTUxJTksrPSJhbmRy
b2lkX2FkYiIKIwkJT25lUGx1cyAzVApBVFRSe2lkUHJvZHVjdH09PSI2NzZjIiwgU1lNTElOSys9
ImFuZHJvaWRfYWRiIgpHT1RPPSJhbmRyb2lkX3VzYl9ydWxlX21hdGNoIgpMQUJFTD0ibm90X1F1
YWxjb21tIgoKIwlTSyBUZWxlc3lzCkFUVFJ7aWRWZW5kb3J9PT0iMWY1MyIsIEVOVnthZGJfdXNl
cn09InllcyIKCiMJU2Ftc3VuZwpBVFRSe2lkVmVuZG9yfSE9IjA0ZTgiLCBHT1RPPSJub3RfU2Ft
c3VuZyIKIwkJRmFsc2UgcG9zaXRpdmUgcHJpbnRlcgpBVFRSe2lkUHJvZHVjdH09PSIzPz8/Iiwg
R09UTz0iYW5kcm9pZF91c2JfcnVsZXNfZW5kIgpFTlZ7YWRiX3VzZXJ9PSJ5ZXMiCiMJCUdhbGF4
eSBpNTcwMApBVFRSe2lkUHJvZHVjdH09PSI2ODFjIiwgRU5We2FkYl9hZGJmYXN0fT0ieWVzIgoj
CQlHYWxheHkgaTU4MDAgKDY4MWM9ZGVidWcsNjYwMT1mYXN0Ym9vdCw2OGEwPW1lZGlhcGxheWVy
KQpBVFRSe2lkUHJvZHVjdH09PSI2ODFjIiwgU1lNTElOSys9ImFuZHJvaWRfYWRiIgpBVFRSe2lk
UHJvZHVjdH09PSI2NjAxIiwgU1lNTElOSys9ImFuZHJvaWRfZmFzdGJvb3QiCkFUVFJ7aWRQcm9k
dWN0fT09IjY4YTkiLCBTWU1MSU5LKz0ibGlibXRwLSVrIiwgRU5We0lEX01UUF9ERVZJQ0V9PSIx
IiwgRU5We0lEX01FRElBX1BMQVlFUn09IjEiCiMJCUdhbGF4eSBpNzUwMApBVFRSe2lkUHJvZHVj
dH09PSI2NjQwIiwgRU5We2FkYl9hZGJmYXN0fT0ieWVzIgojCQlHYWxheHkgaTkwMDAgUywgaTkz
MDAgUzMKQVRUUntpZFByb2R1Y3R9PT0iNjYwMSIsIFNZTUxJTksrPSJhbmRyb2lkX2FkYiIKQVRU
UntpZFByb2R1Y3R9PT0iNjg1ZCIsIE1PREU9IjA2NjAiCkFUVFJ7aWRQcm9kdWN0fT09IjY4YzMi
LCBNT0RFPSIwNjYwIgojCQlHYWxheHkgQWNlIChTNTgzMCkgIkNvb3BlciIKQVRUUntpZFByb2R1
Y3R9PT0iNjg5ZSIsIEVOVnthZGJfYWRiZmFzdH09InllcyIKIwkJR2FsYXh5IFRhYgpBVFRSe2lk
UHJvZHVjdH09PSI2ODc3IiwgRU5We2FkYl9hZGJmYXN0fT0ieWVzIgojCQlHYWxheHkgTmV4dXMg
KEdTTSkKQVRUUntpZFByb2R1Y3R9PT0iNjg1YyIKIwkJR2FsYXh5IENvcmUsIFRhYiAxMC4xLCBp
OTEwMCBTMiwgaTkzMDAgUzMsIE41MTAwIE5vdGUgKDguMCksIEdhbGF4eSBTMyBTSFctTTQ0MFMg
M0cgKEtvcmVhIG9ubHkpCkFUVFJ7aWRQcm9kdWN0fT09IjY4NjAiLCBTWU1MSU5LKz0iYW5kcm9p
ZF9hZGIiCkFUVFJ7aWRQcm9kdWN0fT09IjY4NWUiLCBFTlZ7YWRiX2FkYmZhc3R9PSJ5ZXMiCiMJ
CUdhbGF4eSBpOTMwMCBTMwpBVFRSe2lkUHJvZHVjdH09PSI2ODY2IiwgU1lNTElOSys9ImxpYm10
cC0layIsIEVOVntJRF9NVFBfREVWSUNFfT0iMSIsIEVOVntJRF9NRURJQV9QTEFZRVJ9PSIxIgoj
CQlHYWxheHkgUzQgR1QtSTk1MDAKQVRUUntpZFByb2R1Y3R9PT0iNjg1ZCIsIFNZTUxJTksrPSJh
bmRyb2lkX2FkYiIKR09UTz0iYW5kcm9pZF91c2JfcnVsZV9tYXRjaCIKTEFCRUw9Im5vdF9TYW1z
dW5nIgoKIwlTaGFycApBVFRSe2lkVmVuZG9yfT09IjA0ZGQiLCBFTlZ7YWRiX3VzZXJ9PSJ5ZXMi
CgojCVNvbnkKQVRUUntpZFZlbmRvcn09PSIwNTRjIiwgRU5We2FkYl91c2VyfT0ieWVzIgoKIwlT
b255IEVyaWNzc29uCkFUVFJ7aWRWZW5kb3J9IT0iMGZjZSIsIEdPVE89Im5vdF9Tb255X0VyaWNz
c29uIgpFTlZ7YWRiX3VzZXJ9PSJ5ZXMiCiMJCVhwZXJpYSBYMTAgbWluaQpBVFRSe2lkUHJvZHVj
dH09PSIzMTM3IgpBVFRSe2lkUHJvZHVjdH09PSIyMTM3IiwgU1lNTElOSys9ImFuZHJvaWRfYWRi
IgojCQlYcGVyaWEgWDEwIG1pbmkgcHJvCkFUVFJ7aWRQcm9kdWN0fT09IjMxMzgiCkFUVFJ7aWRQ
cm9kdWN0fT09IjIxMzgiLCBTWU1MSU5LKz0iYW5kcm9pZF9hZGIiCiMJCVhwZXJpYSBYOApBVFRS
e2lkUHJvZHVjdH09PSIzMTQ5IgpBVFRSe2lkUHJvZHVjdH09PSIyMTQ5IiwgU1lNTElOSys9ImFu
ZHJvaWRfYWRiIgojCQlYcGVyaWEgWDEyCkFUVFJ7aWRQcm9kdWN0fT09ImUxNGYiCkFUVFJ7aWRQ
cm9kdWN0fT09IjYxNGYiLCBTWU1MSU5LKz0iYW5kcm9pZF9hZGIiCiMJCVhwZXJpYSBBcmMgUwpB
VFRSe2lkUHJvZHVjdH09PSI0MTRmIiwgRU5We2FkYl9hZGJmYXN0fT0ieWVzIgojCQlYcGVyaWEg
TmVvIFYgKDYxNTY9ZGVidWcsMGRkZT1mYXN0Ym9vdCkKQVRUUntpZFByb2R1Y3R9PT0iNjE1NiIs
IFNZTUxJTksrPSJhbmRyb2lkX2FkYiIKQVRUUntpZFByb2R1Y3R9PT0iMGRkZSIsIFNZTUxJTksr
PSJhbmRyb2lkX2Zhc3Rib290IgojCQlYcGVyaWEgUwpBVFRSe2lkUHJvZHVjdH09PSI1MTY5Iiwg
RU5We2FkYl9hZGJmYXN0fT0ieWVzIgojCQlYcGVyaWEgU1AKQVRUUntpZFByb2R1Y3R9PT0iNjE5
NSIsIEVOVnthZGJfYWRiZmFzdH09InllcyIKIwkJWHBlcmlhIEwKQVRUUntpZFByb2R1Y3R9PT0i
NTE5MiIsIEVOVnthZGJfYWRiZmFzdH09InllcyIKIwkJWHBlcmlhIE1pbmkgUHJvCkFUVFJ7aWRQ
cm9kdWN0fT09IjAxNjYiLCBFTlZ7YWRiX2FkYmZhc3R9PSJ5ZXMiCiMJCVhwZXJpYSBWCkFUVFJ7
aWRQcm9kdWN0fT09IjAxODYiLCBFTlZ7YWRiX2FkYmZhc3R9PSJ5ZXMiCiMJCVhwZXJpYSBBY3Jv
IFMKQVRUUntpZFByb2R1Y3R9PT0iNTE3NiIsIEVOVnthZGJfYWRiZmFzdH09InllcyIKIwkJWHBl
cmlhIFoxIENvbXBhY3QKQVRUUntpZFByb2R1Y3R9PT0iNTFhNyIsIEVOVnthZGJfYWRiZmFzdH09
InllcyIKIwkJWHBlcmlhIFoyCkFUVFJ7aWRQcm9kdWN0fT09IjUxYmEiLCBFTlZ7YWRiX2FkYmZh
c3R9PSJ5ZXMiCiMJCVhwZXJpYSBaMwpBVFRSe2lkUHJvZHVjdH09PSIwMWFmIiwgRU5We2FkYl9h
ZGJmYXN0fT0ieWVzIgojCQlYcGVyaWEgWjMgQ29tcGFjdApBVFRSe2lkUHJvZHVjdH09PSIwMWJi
IiwgRU5We2FkYl9hZGJmYXN0fT0ieWVzIgojCQlYcGVyaWEgWjMrIER1YWwKQVRUUntpZFByb2R1
Y3R9PT0iNTFjOSIsIEVOVnthZGJfYWRiZmFzdH09InllcyIKR09UTz0iYW5kcm9pZF91c2JfcnVs
ZV9tYXRjaCIKTEFCRUw9Im5vdF9Tb255X0VyaWNzc29uIgoKIwlTcHJlYWR0cnVtCkFUVFJ7aWRW
ZW5kb3J9PT0iMTc4MiIsIEVOVnthZGJfdXNlcn09InllcyIKCiMJVCAmIEEgTW9iaWxlIFBob25l
cwpBVFRSe2lkVmVuZG9yfT09IjFiYmIiLCBFTlZ7YWRiX3VzZXJ9PSJ5ZXMiCiMJCUFsY2F0ZWwg
T1Q5OTFECkFUVFJ7aWRQcm9kdWN0fT09IjAwZjIiLCBTWU1MSU5LKz0iYW5kcm9pZF9hZGIiCiMJ
CUFsY2F0ZWwgT1Q2MDEyQQpBVFRSe2lkUHJvZHVjdH09PSIwMTY3IiwgU1lNTElOSys9ImFuZHJv
aWRfYWRiIgoKIwlUZWxlZXBvY2gKQVRUUntpZFZlbmRvcn09PSIyMzQwIiwgRU5We2FkYl91c2Vy
fT0ieWVzIgoKIwlUZXhhcyBJbnN0cnVtZW50cyBVc2JCb290CkFUVFJ7aWRWZW5kb3J9PT0iMDQ1
MSIsIEFUVFJ7aWRQcm9kdWN0fT09ImQwMGYiLCBFTlZ7YWRiX3VzZXJ9PSJ5ZXMiCkFUVFJ7aWRW
ZW5kb3J9PT0iMDQ1MSIsIEFUVFJ7aWRQcm9kdWN0fT09ImQwMTAiLCBFTlZ7YWRiX3VzZXJ9PSJ5
ZXMiCgojCVRvc2hpYmEKQVRUUntpZFZlbmRvcn09PSIwOTMwIiwgRU5We2FkYl91c2VyfT0ieWVz
IgoKIwlXRUFSTkVSUwpBVFRSe2lkVmVuZG9yfT09IjA1YzYiLCBFTlZ7YWRiX3VzZXJ9PSJ5ZXMi
CgojCVhpYW9NaQpBVFRSe2lkVmVuZG9yfSE9IjI3MTciLCBHT1RPPSJub3RfWGlhb01pIgpFTlZ7
YWRiX3VzZXJ9PSJ5ZXMiCiMJCU1pMkEKQVRUUntpZFByb2R1Y3R9PT0iOTA0ZSIsIFNZTUxJTksr
PSJhbmRyb2lkX2FkYiIKQVRUUntpZFByb2R1Y3R9PT0iOTAzOSIsIFNZTUxJTksrPSJhbmRyb2lk
X2FkYiIKIwkJTWkzCkFUVFJ7aWRQcm9kdWN0fT09IjAzNjgiLCBTWU1MSU5LKz0iYW5kcm9pZF9h
ZGIiCiMJCVJlZE1pIDFTIFdDRE1BIChNVFArRGVidWcpCkFUVFJ7aWRQcm9kdWN0fT09IjEyNjgi
LCBTWU1MSU5LKz0iYW5kcm9pZF9hZGIiCiMJCVJlZE1pIC8gUmVkTWkgTm90ZSBXQ0RNQSAoTVRQ
K0RlYnVnKQpBVFRSe2lkUHJvZHVjdH09PSIxMjQ4IiwgU1lNTElOSys9ImFuZHJvaWRfYWRiIgoj
CQlSZWRNaSAxUyAvIFJlZE1pIC8gUmVkTWkgTm90ZSBXQ0RNQSAoUFRQK0RlYnVnKQpBVFRSe2lk
UHJvZHVjdH09PSIxMjE4IiwgU1lNTElOSys9ImFuZHJvaWRfYWRiIgojCQlSZWRNaSAxUyAvUmVk
TWkgLyBSZWRNaSBOb3RlIFdDRE1BIChVc2IrRGVidWcpCkFUVFJ7aWRQcm9kdWN0fT09IjEyMjgi
LCBTWU1MSU5LKz0iYW5kcm9pZF9hZGIiCiMJCVJlZE1pIC8gUmVkTWkgTm90ZSA0RyBXQ0RNQSAo
TVRQK0RlYnVnKQpBVFRSe2lkUHJvZHVjdH09PSIxMzY4IiwgU1lNTElOSys9ImFuZHJvaWRfYWRi
IgojCQlSZWRNaSAvIFJlZE1pIE5vdGUgNEcgV0NETUEgKFBUUCtEZWJ1ZykKQVRUUntpZFByb2R1
Y3R9PT0iMTMxOCIsIFNZTUxJTksrPSJhbmRyb2lkX2FkYiIKIwkJUmVkTWkgLyBSZWRNaSBOb3Rl
IDRHIFdDRE1BIChVc2IrRGVidWcpCkFUVFJ7aWRQcm9kdWN0fT09IjEzMjgiLCBTWU1MSU5LKz0i
YW5kcm9pZF9hZGIiCiMJCVJlZE1pIC8gUmVkTWkgTm90ZSA0RyBDRE1BIChVc2IrRGVidWcpIC8g
TWk0YyAvIE1pNQpBVFRSe2lkUHJvZHVjdH09PSJmZjY4IiwgU1lNTElOSys9ImFuZHJvaWRfYWRi
IgpHT1RPPSJhbmRyb2lkX3VzYl9ydWxlX21hdGNoIgpMQUJFTD0ibm90X1hpYW9NaSIKCiMJWW90
YQpBVFRSe2lkVmVuZG9yfSE9IjI5MTYiLCBHT1RPPSJub3RfWW90YSIKRU5We2FkYl91c2VyfT0i
eWVzIgojICAgWW90YVBob25lMiAoZjAwMz1ub3JtYWwsOTEzOT1kZWJ1ZykKQVRUUntpZFByb2R1
Y3R9PT0iOTEzOSIsIFNZTUxJTksrPSJhbmRyb2lkX2FkYiIKR09UTz0iYW5kcm9pZF91c2JfcnVs
ZV9tYXRjaCIKTEFCRUw9Im5vdF9Zb3RhIgoKIwlXaWxleWZveApBVFRSe2lkVmVuZG9yfT09IjI5
NzAiLCBFTlZ7YWRiX3VzZXJ9PSJ5ZXMiCgojCVlVCkFUVFJ7aWRWZW5kb3J9PT0iMWViZiIsIEVO
VnthZGJfdXNlcn09InllcyIKCiMJWmVicmEKQVRUUntpZFZlbmRvcn0hPSIwNWUwIiwgR09UTz0i
bm90X1plYnJhIgpFTlZ7YWRiX3VzZXJ9PSJ5ZXMiCiMJCVRDNTUKQVRUUntpZFByb2R1Y3R9PT0i
MjEwMSIsIFNZTUxJTksrPSJhbmRyb2lkX2FkYiIKR09UTz0iYW5kcm9pZF91c2JfcnVsZV9tYXRj
aCIKTEFCRUw9Im5vdF9aZWJyYSIKCiMJWlRFCkFUVFJ7aWRWZW5kb3J9PT0iMTlkMiIsIEVOVnth
ZGJfdXNlcn09InllcyIKIwkJQmxhZGUgKDEzNTM9bm9ybWFsLDEzNTE9ZGVidWcpCkFUVFJ7aWRQ
cm9kdWN0fT09IjEzNTEiLCBTWU1MSU5LKz0iYW5kcm9pZF9hZGIiCiMJCUJsYWRlIFMgKENyZXNj
ZW50LCBPcmFuZ2UgU2FuIEZyYW5jaXNjbyAyKSAoMTM1NT1ub3JtYWwsMTM1ND1kZWJ1ZykKQVRU
UntpZFByb2R1Y3R9PT0iMTM1NCIsIFNZTUxJTksrPSJhbmRyb2lkX2FkYiIKCiMJV2lsZXlmb3gK
QVRUUntpZFZlbmRvcn09PSIyOTcwIiwgRU5We2FkYl91c2VyfT0ieWVzIgoKIwlZVQpBVFRSe2lk
VmVuZG9yfT09IjFlYmYiLCBFTlZ7YWRiX3VzZXJ9PSJ5ZXMiCgojCVpVSwpBVFRSe2lkVmVuZG9y
fT09IjJiNGMiLCBFTlZ7YWRiX3VzZXJ9PSJ5ZXMiCgojIFNraXAgb3RoZXIgdmVuZG9yIHRlc3Rz
CkxBQkVMPSJhbmRyb2lkX3VzYl9ydWxlX21hdGNoIgoKIyBTeW1saW5rIHNob3J0Y3V0cyB0byBy
ZWR1Y2UgY29kZSBpbiB0ZXN0cyBhYm92ZQpFTlZ7YWRiX2FkYmZhc3R9PT0ieWVzIiwgRU5We2Fk
Yl9hZGJ9PSJ5ZXMiLCBFTlZ7YWRiX2Zhc3R9PSJ5ZXMiCkVOVnthZGJfYWRifT09InllcyIsIEVO
VnthZGJfdXNlcn09InllcyIsIFNZTUxJTksrPSJhbmRyb2lkX2FkYiIKRU5We2FkYl9mYXN0fT09
InllcyIsIEVOVnthZGJfdXNlcn09InllcyIsIFNZTUxJTksrPSJhbmRyb2lkX2Zhc3Rib290IgoK
IyBFbmFibGUgZGV2aWNlIGFzIGEgdXNlciBkZXZpY2UgaWYgZm91bmQgKGFkZCBhbiAiYW5kcm9p
ZCIgU1lNTElOSykKRU5We2FkYl91c2VyfT09InllcyIsIE1PREU9IjA2NjAiLCBHUk9VUD0iYWRi
dXNlcnMiLCBUQUcrPSJ1YWNjZXNzIiwgU1lNTElOSys9ImFuZHJvaWQiCgojIERldmljZXMgbGlz
dGVkIGhlcmUge2JlZ2luLi4uZW5kfSBhcmUgY29ubmVjdGVkIGJ5IFVTQgpMQUJFTD0iYW5kcm9p
ZF91c2JfcnVsZXNfZW5kIgo=
EOF

groupadd adbusers
usermod -a -G adbusers root
usermod -a -G adbusers vagrant
chmod 644 /etc/udev/rules.d/51-android.rules
# chcon "system_u:object_r:udev_rules_t:s0" /etc/udev/rules.d/51-android.rules

cat <<-EOF > /home/vagrant/lineage-build.sh
#!/bin/bash -e

# Build Lineage for Motorol Photon Q by default - because physical keyboards eat virtual keyboards
# for breakfast, brunch and then dinner.

export DEVICE=\${DEVICE:="pro1"}
export BRANCH=\${BRANCH:="lineage-18.1"}
export VENDOR=\${VENDOR:="fxtec"}

export NAME=\${NAME:="Robox Build Robot"}
export EMAIL=\${EMAIL:="robot@lineageos.local"}

echo DEVICE=\$DEVICE
echo BRANCH=\$BRANCH
echo VENDOR=\$VENDOR
echo
echo NAME=\$NAME
echo EMAIL=\$EMAIL
echo
echo "Override the above environment variables to alter the build configuration."
echo
echo
sleep 10

# Setup the branch and enable the distributed cache.
export USE_CCACHE=1
export CCACHE_DIR="\$HOME/cache"
export CCACHE_COMPRESS=1
export TMPDIR="\$HOME/temp"
export PROCESSOR_COUNT=\$(nproc)
export REPO_GROUPS=\${REPO_GROUPS:="default,-darwin"}

# Jack is the Java compiler used by LineageOS 14.1+, and it is memory hungry.
# We specify a memory limit of 8gb to avoid 'out of memory' errors.
export ANDROID_JACK_VM_ARGS="-Dfile.encoding=UTF-8 -XX:+TieredCompilation -Xmx8G"

# If the environment indicates we should use Java 7 then run update alternatives to enable it.
export USE_JAVA7=\${USE_JAVA7:="false"}

# If the environment indicates we should use Java 7, then we enable it.
if [ "\$USE_JAVA7" = "true" ]; then
  sudo update-java-alternatives -s java-1.7.0-openjdk-amd64
else
  sudo update-java-alternatives -s java-1.8.0-openjdk-amd64
fi

# Make the directories.
mkdir -p \$HOME/temp && mkdir -p \$HOME/cache && mkdir -p \$HOME/android/lineage

# Goto the build root.
cd \$HOME/android/lineage

# Configure the default git username and email address.
git config --global user.name "\$NAME"
git config --global user.email "\$EMAIL"
git config --global color.ui false

# Initialize the repo.
repo init -u https://github.com/LineageOS/android.git -b \$BRANCH -g \${REPO_GROUPS}

# Set up the blob source.
mkdir -p .repo/local_manifests
if [ -f \$HOME/local_manifest.xml ]; then
cp \$HOME/local_manifest.xml .repo/local_manifests/
else
cat <<-END > .repo/local_manifests/muppets-\$VENDOR.xml
<?xml version="1.0" encoding="UTF-8"?>
<manifest>
  <project name="TheMuppets/proprietary_vendor_\$VENDOR" path="vendor/\$VENDOR" depth="1" />
</manifest>
END
fi

# Download the source code.
let JOBS=\${PROCESSOR_COUNT}*2
repo --color=never sync --quiet --jobs=\${JOBS} --current-branch --no-clone-bundle --no-tags

# Setup the environment.
source build/envsetup.sh

# Reduce the amount of memory required during compilation.
sed -i -e "s/-Xmx2048m/-Xmx4096m/g" \$HOME/android/lineage/build/tools/releasetools/common.py

# Download and configure the environment for the device.
breakfast \$DEVICE || ( printf "\n\n\nBuild failed. (breakfast)\n\n\n"; exit 1 )

# Setup the cache.
cd \$HOME/android/lineage/

export CCACHE_EXEC="prebuilts/misc/linux-x86/ccache/ccache"

if [ ! -x "\$CCACHE_EXEC" ]; then
  export CCACHE_EXEC="\$(which ccache)"
fi

"\$CCACHE_EXEC" -M 20G

BUILDSTAMP=\`date --utc +'%Y%m%d'\`

# Start the build.
croot
brunch \$DEVICE || ( printf "\n\n\nBuild failed. (brunch)\n\n\n"; exit 1 )

# Calculate the filename.
VERSION_NAME="\$BRANCH"

# A few select branches got rebranded
if [[ "\$VERSION_NAME" =~ ^cm-(11\.0|13\.0|14\.1)$ ]]; then
  VERSION_NAME=\${VERSION_NAME/cm-/lineage-}
fi

# 11.0 was only designated as '11'
if [[ "\$VERSION_NAME" =~ "lineage-11.0" ]]; then
  VERSION_NAME="lineage-11"
fi

DIRIMAGE="\$HOME/android/lineage/out/target/product/\$DEVICE"
SYSIMAGE="\$DIRIMAGE/\$VERSION_NAME-\$BUILDSTAMP-UNOFFICIAL-\$DEVICE.zip"

# Verify the md5sum if it exists, otherwise generate it.
MD5IMAGESUM="\$SYSIMAGE.md5sum"
if [ -f "\$MD5IMAGESUM" ]; then
  (cd "\$DIRIMAGE" && md5sum -c "\$MD5IMAGESUM") || ( printf "\n\n\nThe MD5 hash failed to validate.\n\n\n"; exit 1 )
else
  (cd "\$DIRIMAGE" && md5sum "\$SYSIMAGE" > "\$MD5IMAGESUM")
fi

# Verify a sha256sum, or generate it.
SHAIMAGESUM="\$SYSIMAGE.sha256sum"
if [ -f "\$SHAIMAGESUM" ]; then
  (cd "\$DIRIMAGE" && sha256sum -c "\$SHAIMAGESUM") || ( printf "\n\n\nThe SHA256 hash failed to validate.\n\n\n"; exit 1 )
else
  (cd "\$DIRIMAGE" && sha256sum "\$SYSIMAGE" > "\$SHAIMAGESUM")
fi

# See what the output directory holds.
ls -alh "\$SYSIMAGE" "\$MD5IMAGESUM" "\$SHAIMAGESUM"

# Push the new system image to the device.
# adb push "\$SYSIMAGE" /sdcard/
# env > ~/env.txt
EOF

chown vagrant:vagrant /home/vagrant/lineage-build.sh
chmod +x /home/vagrant/lineage-build.sh

# Customize the message of the day
cat <<-EOF > /etc/motd
  
  # Building LineageOS
  # Turning craptastic into the fantastic.
  
  # To build LineageOS 14.1 (or newer) for any officially supported, or device  
  # which previously had official support, simply supply the appropriate 
  # vendor/device/branch params. Some examples follow.
  
  # To build LineageOS 18.1 for the Google Pixel 5a use the following.
  env VENDOR=google DEVICE=barbet BRANCH=lineage-18.1 ./lineage-build.sh

  # To build LineageOS 17.1 for the Fxtec Pro1.
  env VENDOR=fxtec DEVICE=pro1 BRANCH=lineage-17.1 ./lineage-build.sh
  
  # To build LineageOS 16.0 for the Samsung Galaxy Tab S2.
  env VENDOR=samsung DEVICE=gts210vewifi BRANCH=lineage-16.0 ./lineage-build.sh

  # To build LineageOS 15.1 for the Motorola Z2 Force.
  env VENDOR=motorola DEVICE=nash BRANCH=lineage-15.1 ./lineage-build.sh

  # To build LineageOS 14.1 for the Motorola Photon Q
  env VENDOR=motorola DEVICE=xt897 BRANCH=cm-14.1 ./lineage-build.sh
  
  # To build versions of LineageOS versions between 11.0 and 13.0, enable Java 7, 
  # for LineageOS 13.0 on the Sony Xperia T, use the following.
  env VENDOR=sony DEVICE=mint BRANCH=cm-13.0 USE_JAVA7=true ./lineage-build.sh

  # Finally, to build LineageOS for devices without official support, or to 
  # simply override the default repository configuration, create a 
  # local_manifest.xml file in the home directory. Doing so will disable the 
  # default device manifest generated by this script, in favor of the supplied 
  # manifest file. For example, to build LineageOS 18.1 for an unlocked
  # Amazon Fire HD 8 (8th generation), you could run the following.
  export VENDOR=amazon DEVICE=karnak BRANCH=lineage-18.1 
  curl -LOs https://raw.github.com/craptastic-droids/manifests/master/karnak.xml
  mv karnak.xml local_manifest.xml && ./lineage-build.sh

EOF
