.PHONY: run test app

run:
	swift run TiboResetNotifier

test:
	swift run TiboResetNotifierChecks

app:
	./scripts/build-app.sh
