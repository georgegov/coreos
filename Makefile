default:
	@echo "Must specify target"

transpile:
	./ct -pretty -strict --in-file config.yml --out-file config.json

vm-get-ignition-file:
	wget https://raw.githubusercontent.com/georgegov/coreos/master/config.json

vm-install-coreos:
	coreos-install -d /dev/sda -C stable -i config.json

vm-get-setup-script:
	wget https://raw.githubusercontent.com/georgegov/coreos/master/setup-kubegrid.sh

vm-run-setup-script:
	./setup-kubegrid.sh
