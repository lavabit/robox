#!/bin/bash

# Disable IPv6 or DNS names will resolve to AAAA yet connections will fail.
sysctl net.ipv6.conf.all.disable_ipv6=1

# To allow for autmated installs, we disable interactive configuration steps.
export DEBIAN_FRONTEND=noninteractive

# Install developer tools.
apt-get --assume-yes install vim vim-nox wget curl gnupg mlocate sysstat lsof pciutils usbutils

# Install the build dependencies.
apt-get --assume-yes install bc bison build-essential curl flex g++-multilib gcc-multilib git gnupg gperf imagemagick lib32ncurses5-dev lib32readline6-dev lib32z1-dev libesd0-dev liblz4-tool libncurses5-dev libsdl1.2-dev libssl-dev libwxgtk3.0-dev libxml2 libxml2-utils lzop pngcrush rsync schedtool squashfs-tools xsltproc zip zlib1g-dev ninja-build

# Java 8 Support
apt-get --assume-yes install openjdk-8-jdk openjdk-8-jdk-headless openjdk-8-jre openjdk-8-jre-headless

# Java dependencies
apt-get --assume-yes install maven libatk-wrapper-java libatk-wrapper-java-jni libpng16-16 libsctp1

# Download the OpenJDK 1.7 packages.
curl --output openjdk-7-jre_7u121-2.6.8-2_amd64.deb https://mirrors.kernel.org/debian/pool/main/o/openjdk-7/openjdk-7-jre_7u121-2.6.8-2_amd64.deb
curl --output openjdk-7-jre-headless_7u121-2.6.8-2_amd64.deb https://mirrors.kernel.org/debian/pool/main/o/openjdk-7/openjdk-7-jre-headless_7u121-2.6.8-2_amd64.deb
curl --output openjdk-7-jdk_7u121-2.6.8-2_amd64.deb https://mirrors.kernel.org/debian/pool/main/o/openjdk-7/openjdk-7-jdk_7u121-2.6.8-2_amd64.deb
curl --output libjpeg62-turbo_1.5.1-2_amd64.deb https://mirrors.kernel.org/debian/pool/main/libj/libjpeg-turbo/libjpeg62-turbo_1.5.1-2_amd64.deb

# Install via dpkg.
dpkg -i openjdk-7-jre_7u121-2.6.8-2_amd64.deb openjdk-7-jre-headless_7u121-2.6.8-2_amd64.deb openjdk-7-jdk_7u121-2.6.8-2_amd64.deb libjpeg62-turbo_1.5.1-2_amd64.deb

# Assuming the OpenJDK has dependencies... install them here.
apt --assume-yes install -f

# Setup OpenJDK 1.7 as the default, which is required for the 13.0 branch.
update-java-alternatives -s java-1.7.0-openjdk-amd64

# Delete the downloaded Java 7 packages.
rm --force openjdk-7-jre_7u121-2.6.8-2_amd64.deb openjdk-7-jre-headless_7u121-2.6.8-2_amd64.deb openjdk-7-jdk_7u121-2.6.8-2_amd64.deb libjpeg62-turbo_1.5.1-2_amd64.deb

# Enable the source code repositories.
sed -i -e "s|.*deb-src |deb-src |g" /etc/apt/sources.list
apt-get --assume-yes update

# Ensure the dependencies required to compile git are available.
apt-get --assume-yes install build-essential fakeroot dpkg-dev
apt-get --assume-yes build-dep git

# The build-dep command will remove the OpenSSL version of libcurl, so we have to
# install here instead.
apt-get --assume-yes install libcurl4-openssl-dev

# Download the git sourcecode.
mkdir -p $HOME/git-openssl && cd $HOME/git-openssl
apt-get source git
dpkg-source -x `find * -type f -name *.dsc`
cd `find * -maxdepth 0 -type d`

# Recompile git using OpenSSL instead of gnutls.
sed -i -e "s|libcurl4-gnutls-dev|libcurl4-openssl-dev|g" debian/control
sed -i -e "/TEST[ ]*=test/d" debian/rules
dpkg-buildpackage -rfakeroot -b

# Insall the new version.
dpkg -i `find ../* -type f -name *amd64.deb`

# Cleanup the git build directory.
cd $HOME && rm --force --recursive $HOME/git-openssl

# Download the Android tools.
curl --output platform-tools-latest-linux.zip https://dl.google.com/android/repository/platform-tools-latest-linux.zip

# Install the platform tools.
unzip platform-tools-latest-linux.zip -d /usr/local/

# Delete the downloaded tools archive.
rm --force platform-tools-latest-linux.zip

# Ensure the platform tools are in the binary search path.
printf "PATH=/usr/local/platform-tools/:$PATH\n" > /etc/profile.d/platform-tools.sh

# Install the repo utility.
curl https://storage.googleapis.com/git-repo-downloads/repo > /usr/bin/repo
chmod a+x /usr/bin/repo

cat <<-EOF > /home/vagrant/lineage-build.sh
#!/bin/bash

# The Motorol Photon Q by default - because physical keyboards eat virtual keyboards
# for breakfast, brunch and then dinner.

export DEVICE=\${DEVICE:="xt897"}
export BRANCH=\${BRANCH:="cm-14.1"}
export VENDOR=\${VENDOR:="motorola"}

export NAME=\${NAME:="Ladar Levison"}
export EMAIL=\${EMAIL:="ladar@lavabit.com"}

echo DEVICE=\$DEVICE
echo BRANCH=\$BRANCH
echo VENDOR=\$VENDOR
echo
echo NAME=\$NAME
echo EMAIL=\$EMAIL
echo
echo "Override the above environment variables in your Vagrantfile to alter the build configuration."
echo
echo
sleep 10

# Setup the branch and enable the distributed cache.
export USE_CCACHE=1
export TMPDIR="\$HOME/temp"
export ANDROID_CCACHE_SIZE="20G"
export ANDROID_CCACHE_DIR="\$HOME/cache"

# Jack is the Java compiler used by LineageOS 14.1+. Run this command to avoid running out of memory.
export ANDROID_JACK_VM_ARGS="-Dfile.encoding=UTF-8 -XX:+TieredCompilation -Xmx2G"

# If the environment indicates we should use Java 8 then run update alternatives to enable it.
export EXPERIMENTAL_USE_JAVA8=\${EXPERIMENTAL_USE_JAVA8:="true"}

# If the environment indicates we should use Java 7, then we enable it.
if [ "\$EXPERIMENTAL_USE_JAVA8" = "true" ]; then
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

# Initialize the repo and download the source code.
repo init -u https://github.com/LineageOS/android.git -b \$BRANCH
repo --color=never sync --quiet --jobs=2

# Setup the environment.
source build/envsetup.sh

# Reduce the amount of memory required during compilation.
# sed -i -e "s/-Xmx2048m/-Xmx512m/g" \$HOME/android/lineage/build/tools/releasetools/common.py

# Download and configure the environment for the device.
breakfast \$DEVICE

# # Find the latest upstream build.
# ARCHIVE=\`curl --silent https://download.lineageos.org/\$DEVICE | grep href | grep https://mirrorbits.lineageos.org/full/\$DEVICE/ | head -1 | awk -F'"' '{print \$2}'\`
#
# # Create a system dump directory.
# mkdir -p \$HOME/android/system_dump/ && cd \$HOME/android/system_dump/
#
# # Download the archive.
# curl --location --output lineage-archive.zip "\$ARCHIVE"
#
# # Extract the system blocks.
# unzip lineage-archive.zip system.transfer.list system.new.dat
#
# # Clone the sdat2img tool.
# git clone https://github.com/xpirt/sdat2img
#
# # Convert the system block file into an image.
# python sdat2img/sdat2img.py system.transfer.list system.new.dat system.img
#
# # Mount the system image.
# mkdir -p \$HOME/android/system/
# sudo mount system.img \$HOME/android/system/

# Change to the device directory and run the extraction script.
# cd \$HOME/android/lineage/device/\$VENDOR/\$DEVICE
# ./extract-files.sh \$HOME/android/system_dump/system
#
# # Unmount the system dump.
# sudo umount \$HOME/android/system_dump/system
# rm -rf \$HOME/android/system_dump/

# Extract the vendor specific blobs.
mkdir -p \$HOME/android/vendor/system/
tar -xzv -C \$HOME/android/vendor/ -f \$HOME/system-blobs.tar.gz

# Change to the xt897 directory and run the extraction script.
cd \$HOME/android/lineage/device/\$VENDOR/\$DEVICE
./extract-files.sh \$HOME/android/vendor/system/

# Cleanup the vendor blob files.
rm -rf \$HOME/android/vendor/

# Setup the environment.
cd \$HOME/android/lineage/ && source build/envsetup.sh
breakfast \$DEVICE

# Setup the cache.
cd \$HOME/android/lineage/
prebuilts/misc/linux-x86/ccache/ccache -M 20G

# Start the build.
croot
brunch \$DEVICE

# Calculate the filename.
BUILDSTAMP=\`date +'%Y%m%d'\`
DIRIMAGE="\$HOME/android/lineage/out/target/product/\$DEVICE"
SYSIMAGE="\$DIRIMAGE/lineage-14.1-\$BUILDSTAMP-UNOFFICIAL-\$DEVICE.zip"
SYSIMAGESUM="\$DIRIMAGE/lineage-14.1-\$BUILDSTAMP-UNOFFICIAL-\$DEVICE.zip.md5sum"
#RECIMAGE="lineage-\$BUILDVERSION-\$BUILDSTAMP-UNOFFICIAL-\$DEVICE-recovery.img"

# Verify the image checksum.
md5sum -c "\$SYSIMAGESUM"

# See what the output directory holds.
ls -alh "\$SYSIMAGE" "\$SYSIMAGESUM"

# Push the new system image to the device.
# adb push "\$SYSIMAGE" /sdcard/
env > ~/env.txt 
EOF

chown vagrant:vagrant /home/vagrant/system-blobs.tar.gz
chown vagrant:vagrant /home/vagrant/lineage-build.sh
chmod +x /home/vagrant/lineage-build.sh

# Customize the message of the day
printf "Lineage Development Environment\nTo download and compile Lineage, just execute the lineage-build.sh script.\n\n" > /etc/motd
