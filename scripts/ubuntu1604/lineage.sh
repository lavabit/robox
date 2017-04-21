#!/bin/bash -eux

# Disable IPv6 or DNS names will resolve to AAAA yet connections will fail.
sysctl net.ipv6.conf.all.disable_ipv6=1

# To allow for autmated installs, we disable interactive configuration steps.
export DEBIAN_FRONTEND=noninteractive

# Install developer tools.
apt-get --assume-yes install vim vim-nox wget curl gnupg mlocate sysstat lsof pciutils usbutils

# Install the build dependencies.
apt-get --assume-yes install bc bison build-essential curl flex g++-multilib gcc-multilib git gnupg gperf imagemagick lib32ncurses5-dev lib32readline6-dev lib32z1-dev libesd0-dev liblz4-tool libncurses5-dev libsdl1.2-dev libssl-dev libwxgtk3.0-dev libxml2 libxml2-utils lzop pngcrush rsync schedtool squashfs-tools xsltproc zip zlib1g-dev openjdk-8-jdk

# Java dependencies
apt-get --assume-yes install maven libatk-wrapper-java libatk-wrapper-java-jni libpng16-16 libsctp1

# If the Java 8 environment variables wasn't provided, then we need to install Java 7.
# if [[ $EXPERIMENTAL_USE_JAVA8 != ^true$ ]]; then

  # Download the OpenJDK 1.7 packages.
  curl --output openjdk-7-jre_7u121-2.6.8-2_amd64.deb https://mirrors.kernel.org/debian/pool/main/o/openjdk-7/openjdk-7-jre_7u121-2.6.8-2_amd64.deb
  curl --output openjdk-7-jre-headless_7u121-2.6.8-2_amd64.deb https://mirrors.kernel.org/debian/pool/main/o/openjdk-7/openjdk-7-jre-headless_7u121-2.6.8-2_amd64.deb
  curl --output openjdk-7-jdk_7u121-2.6.8-2_amd64.deb https://mirrors.kernel.org/debian/pool/main/o/openjdk-7/openjdk-7-jdk_7u121-2.6.8-2_amd64.deb
  curl --output libjpeg62-turbo_1.5.1-2_amd64.deb https://mirrors.kernel.org/debian/pool/main/libj/libjpeg-turbo/libjpeg62-turbo_1.5.1-2_amd64.deb

  # Install via dpkg.
  dpkg -i openjdk-7-jre_7u121-2.6.8-2_amd64.deb openjdk-7-jre-headless_7u121-2.6.8-2_amd64.deb openjdk-7-jdk_7u121-2.6.8-2_amd64.deb libjpeg62-turbo_1.5.1-2_amd64.deb

  # Assuming the OpenJDK has dependencies... install them here.
  apt --assume-yes install -f

  # Setup OpenJDK 1.7 if building the 13.0 branch.
  update-java-alternatives -s java-1.7.0-openjdk-amd64

  # Delete the downloaded Java 7 packages.
  rm --force openjdk-7-jre_7u121-2.6.8-2_amd64.deb openjdk-7-jre-headless_7u121-2.6.8-2_amd64.deb openjdk-7-jdk_7u121-2.6.8-2_amd64.deb libjpeg62-turbo_1.5.1-2_amd64.deb

# else
#   printf "export EXPERIMENTAL_USE_JAVA8=true\n" > /etc/profile.d/java8.sh
# fi

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

# # Do we need to recompile git? If so, retrieve it here.
# curl --output git-2.12.2.tar.gz https://www.kernel.org/pub/software/scm/git/git-2.12.2.tar.gz
# curl --output git-manpages-2.12.2.tar.gz https://www.kernel.org/pub/software/scm/git/git-manpages-2.12.2.tar.gz
#
# # Extrract, compile and install the git tarball.
# tar xzvf git-2.12.2.tar.gz
# cd git-2.12.2 && ./configure && make && make install && cd ..
#
# # Install the man pages.
# tar -xzv -C /usr/local/share/man/ -f git-manpages-2.12.2.tar.gz
#
# # Cleanup the downloaded git code.
# rm --recursive --force git-2.12.2 git-2.12.2.tar.gz git-manpages-2.12.2.tar.gz

cat <<-EOF > /home/vagrant/lineage-build.sh
#!/bin/bash -eux

# The Motorol Photon Q by default - because physical keyboards eat virtual keyboards
# for breakfast, brunch and then dinner.

export DEVICE=\${DEVICE:="xt897"}
export BRANCH=\${BRANCH:="cm-13.0"}
export VENDOR=\${VENDOR:="motorola"}

export NAME=\${NAME:="Ladar Levison"}
export EMAIL=\${EMAIL:="ladar@lavabit.com"}

# Setup the branch and enable the distributed cache.
export USE_CCACHE=1
export TMPDIR="\$HOME/temp"
export ANDROID_CCACHE_SIZE="20G"
export ANDROID_CCACHE_DIR="\$HOME/cache"

# Can we get gnutls to play nicely with the droid source repos...
#export GIT_CURL_VERBOSE=1
export GIT_HTTP_MAX_REQUESTS=1

# Make the directories.
mkdir -p \$HOME/temp && mkdir -p \$HOME/cache && mkdir -p \$HOME/android/lineage

# Goto the build root.
cd \$HOME/android/lineage

# Configure the default git username and email address.
git config --global user.name "\$NAME"
git config --global user.email "\$EMAIL"
git config --global color.ui false
# git config --global http.sslVersion tlsv1.2

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
# ARCHIVE=`curl --silent https://download.lineageos.org/\$DEVICE | grep href | grep https://mirrorbits.lineageos.org/full/\$DEVICE/ | head -1 | awk -F'"' '{print \$2}'`
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
# cd \$HOME/android/lineage/device/\$VENDOR/$DEVICE
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
BUILDSTAMP=`date +'%Y%m%d'`
DIRIMAGE="\$HOME/android/lineage/out/target/product/\$DEVICE/"
SYSIMAGE="\$DIRIMAGE/lineage-\$BUILDVERSION-\$BUILDSTAMP-UNOFFICIAL-\$DEVICE.zip"
SYSIMAGESUM="\$DIRIMAGE/lineage-\$BUILDVERSION-\$BUILDSTAMP-UNOFFICIAL-\$DEVICE.zip.md5sum"
#RECIMAGE="lineage-\$BUILDVERSION-\$BUILDSTAMP-UNOFFICIAL-\$DEVICE-recovery.img"

# Verify the image checksum.
md5sum -c "\$SYSIMAGESUM"

# See what the output directory holds.
ls -alh "SYSIMAGE" "SYSIMAGESUM"

# Push the new system image to the device.
# adb push "\$SYSIMAGE" /sdcard/

EOF
