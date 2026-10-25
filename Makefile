FLUTTER ?= fvm flutter
DART ?= fvm dart
# Test files or folders for make test; empty runs all.
TESTS ?=
# Packages for make upgrade; empty upgrades all within the constraints.
PACKAGES ?=

.PHONY: setup upgrade l10n codegen schema format format-check analyze test update-goldens check integration-test run run-profile run-release build-android build-ios

setup:
	fvm install
	$(FLUTTER) pub get

upgrade:
	$(FLUTTER) pub upgrade $(PACKAGES)

l10n:
	$(FLUTTER) gen-l10n

codegen:
	$(DART) run drift_dev schema steps drift_schemas/ lib/data/database/app_database.steps.dart
	$(DART) run build_runner build
	$(DART) run drift_dev schema generate drift_schemas/ test/data/database/generated/

schema: codegen
	$(DART) run drift_dev schema dump lib/data/database/app_database.dart drift_schemas/

format:
	$(DART) format .

format-check:
	$(DART) format --output=none --set-exit-if-changed .

analyze: l10n codegen
	$(FLUTTER) analyze

# A zone with daylight saving time, so the calendar date tests can fail.
test: l10n codegen
	TZ=Europe/Berlin $(FLUTTER) test $(TESTS)

# Golden reference images are made on macOS, which CI runs on as well.
update-goldens: l10n codegen
	TZ=Europe/Berlin $(FLUTTER) test --update-goldens $(TESTS)

check: format-check analyze test

# flutter test uninstalls the app after integration tests, and with it all data.
integration-test: l10n codegen
	$(FLUTTER) test integration_test --no-uninstall

run: codegen
	$(FLUTTER) run

# Debug builds always stutter; judge smoothness in profile mode on a device.
run-profile: codegen
	$(FLUTTER) run --profile

# Shows what only a release build lacks, such as permissions in the main manifest.
run-release: codegen
	$(FLUTTER) run --release

build-android: codegen
	$(FLUTTER) build apk --debug

build-ios: codegen
	$(FLUTTER) build ios --debug --no-codesign
