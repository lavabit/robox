#!/bin/bash



# The armel (ARM EABI) port targets older 32-bit ARM devices (aka armv6), like those used in NAS hardware and *plug computers. The armhf (ARM hard float) port supports newer 32-bit devices (aka armv7),

# Handle the arch types.
if [ "$ARCH" == "x64" ] || [ "$ARCH" == "x86_64" ] || [ "$ARCH" == "amd64" ]; then
  ARCH="amd64"
elif [ "$ARCH" == "x32" ] || [ "$ARCH" == "x86" ] || [ "$ARCH" == "i386" ] || [ "$ARCH" == "i686" ]; then
  ARCH="i386"
elif [ "$ARCH" == "a64" ] || [ "$ARCH" == "aarch64" ] || [ "$ARCH" == "arm64" ] || [ "$ARCH" == "arm64eb" ]|| [ "$ARCH" == "arm64le" ]; then
  ARCH="arm64"
elif [ "$ARCH" == "a32" ] || [ "$ARCH" == "armv7" ] || [ "$ARCH" == "armv6" ] || [ "$ARCH" == "arm" ] || [ "$ARCH" == "armeb" ] || [ "$ARCH" == "armle" ] || [ "$ARCH" == "armel" ] || [ "$ARCH" == "armhf" ]; then
  ARCH="arm"
elif [ "$ARCH" == "m64" ] || [ "$ARCH" == "mips64le" ] || [ "$ARCH" == "mips64el" ] || [ "$ARCH" == "mips64hfel" ]; then
  ARCH="mips64le"
elif [ "$ARCH" == "mips64" ] || [ "$ARCH" == "mips64hf" ] ; then
  ARCH="mips64"
elif [ "$ARCH" == "m32" ] || [ "$ARCH" == "mips" ] || [ "$ARCH" == "mips32" ] || [ "$ARCH" == "mipsn32" ] || [ "$ARCH" == "mipshf" ] ; then
  ARCH="mips"
elif [ "$ARCH" == "mipsle" ] || [ "$ARCH" == "mipsel" ] || [ "$ARCH" == "mipselhf" ]; then
  ARCH="mipsle"
elif [ "$ARCH" == "p64" ] || [ "$ARCH" == "ppc64le" ]; then
  ARCH="ppc64le"
elif [ "$ARCH" == "ppc64" ] || [ "$ARCH" == "power64" ] || [ "$ARCH" == "powerpc64" ]; then
  ARCH="ppc64"
elif [ "$ARCH" == "p32" ] || [ "$ARCH" == "ppc32" ] || [ "$ARCH" == "power" ] || [ "$ARCH" == "power32" ] || [ "$ARCH" == "powerpc" ] || [ "$ARCH" == "powerpc32" ] || [ "$ARCH" == "powerpcspe" ]; then
  ARCH="ppc"
elif [ "$ARCH" == "r64" ] || [ "$ARCH" == "riscv64" ] || [ "$ARCH" == "riscv64sf" ]; then
  ARCH="riscv64"
elif [ "$ARCH" == "r32" ] || [ "$ARCH" == "riscv" ] || [ "$ARCH" == "riscv32" ]; then
  ARCH="riscv"
else
  printf "\n${T_YEL}  The architecture is unrecognized. Passing it verbatim to the cloud. [ arch = ${ARCH} ]${T_RESET}\n\n" >&2
fi