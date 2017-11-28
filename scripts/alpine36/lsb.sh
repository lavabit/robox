#!/bin/bash -eux

tee /usr/bin/lsb_release <<-EOF
#!/bin/bash

printf "Distributor ID:	Alpine\n"

EOF

chmod 755 /usr/bin/lsb_release

# So the vagrant halt command works properly.
tee /usr/sbin/shutdown <<-EOF
#!/bin/bash
sudo /sbin/poweroff
EOF

chmod 755 /usr/sbin/shutdown
