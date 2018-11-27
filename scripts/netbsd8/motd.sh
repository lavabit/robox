#!/bin/bash -eux

sed -i -e "s/\(cmp -s \$T \/etc\/motd || cp \$T \/etc\/motd\)/# \\1/g" /etc/rc 

cat << EOF > /etc/motd
EOF
