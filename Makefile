default:
	@echo "Must specify target"

transpile:
	./ct -pretty -strict --in-file config.yml --out-file config.json
