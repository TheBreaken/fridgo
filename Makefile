FLUTTER ?= fvm flutter
DART ?= fvm dart

.PHONY: setup l10n format format-check analyze test check run build-android build-ios

setup:
	fvm install
	$(FLUTTER) pub get

l10n:
	$(FLUTTER) gen-l10n

format:
	$(DART) format .

format-check:
	$(DART) format --output=none --set-exit-if-changed .

analyze: l10n
	$(FLUTTER) analyze

test: l10n
	$(FLUTTER) test

check: format-check analyze test

run:
	$(FLUTTER) run

build-android:
	$(FLUTTER) build apk --debug

build-ios:
	$(FLUTTER) build ios --debug --no-codesign
