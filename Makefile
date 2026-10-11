FLUTTER ?= fvm flutter
DART ?= fvm dart

.PHONY: setup format format-check analyze test check run build-android build-ios

setup:
	fvm install
	$(FLUTTER) pub get

format:
	$(DART) format .

format-check:
	$(DART) format --output=none --set-exit-if-changed .

analyze:
	$(FLUTTER) analyze

test:
	$(FLUTTER) test

check: format-check analyze test

run:
	$(FLUTTER) run

build-android:
	$(FLUTTER) build apk --debug

build-ios:
	$(FLUTTER) build ios --debug --no-codesign
