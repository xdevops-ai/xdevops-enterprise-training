.PHONY: public-check validate pycheck build stage prod preflight destroy

public-check:
	./scripts/public-release-check.sh

validate: public-check
	./scripts/validate.sh

pycheck:
	python3 -m compileall -q services

build:
	./scripts/build-images.sh

stage:
	./scripts/deploy.sh stage

prod:
	./scripts/deploy.sh prod

preflight:
	./scripts/preflight.sh

destroy:
	@echo "Use: CONFIRM_DESTROY=YES ./scripts/destroy.sh"
