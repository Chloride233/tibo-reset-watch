.PHONY: run test app install web windows-dev windows-build stream-check stream-start

run:
	swift run TiboResetNotifier

test:
	swift run TiboResetNotifierChecks

app:
	./scripts/build-app.sh

install: app
	./scripts/install-app.sh

web:
	python3 -m http.server 8080 --directory web

windows-dev:
	npm start

windows-build:
	npm run windows:build

stream-check:
	npm run stream:check

stream-start:
	npm run stream:start
