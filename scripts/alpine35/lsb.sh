#!/bin/bash -eux

tee /usr/bin/lsb_release <<-EOF
#!/bin/bash

printf "Distributor ID:	Alpine\n"

EOF

chmod 755 /usr/bin/lsb_release
