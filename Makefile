.PHONY: run test app install

run:
	swift run TiboResetNotifier

test:
	swift run TiboResetNotifierChecks

app:
	./scripts/build-app.sh

install: app
	./scripts/install-app.sh
