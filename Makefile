FLUTTER ?= fvm flutter
DART ?= fvm dart

.PHONY: setup l10n codegen schema format format-check analyze test check run build-android build-ios

setup:
	fvm install
	$(FLUTTER) pub get

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

test: l10n codegen
	$(FLUTTER) test

check: format-check analyze test

run: codegen
	$(FLUTTER) run

build-android: codegen
	$(FLUTTER) build apk --debug

build-ios: codegen
	$(FLUTTER) build ios --debug --no-codesign
