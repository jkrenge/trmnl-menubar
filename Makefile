APP = Menu Bar Viewer for TRMNL.app
BIN = "$(APP)/Contents/MacOS/TRMNL"
BUNDLE_ID = com.jkrenge.trmnl-menubar

# Signing settings live in local.mk (gitignored), so nothing personal is committed. See README.
-include local.mk
SIGN_IDENTITY ?= -

build: icon/AppIcon-1024.png
	rm -rf "$(APP)" build && mkdir -p "$(APP)/Contents/MacOS" "$(APP)/Contents/Resources" build
	swiftc -O -parse-as-library -target arm64-apple-macos14 TRMNL.swift -o build/TRMNL-arm64
	swiftc -O -parse-as-library -target x86_64-apple-macos14 TRMNL.swift -o build/TRMNL-x86_64
	lipo -create build/TRMNL-arm64 build/TRMNL-x86_64 -output $(BIN)
	cp Info.plist "$(APP)/Contents/"
	mkdir -p build/Assets.xcassets/AppIcon.appiconset
	for s in 16 32 128 256 512; do \
		sips -z $$s $$s icon/AppIcon-1024.png --out build/Assets.xcassets/AppIcon.appiconset/$$s.png >/dev/null; \
		sips -z $$((s*2)) $$((s*2)) icon/AppIcon-1024.png --out build/Assets.xcassets/AppIcon.appiconset/$$s@2x.png >/dev/null; \
	done
	cp icon/Contents.json build/Assets.xcassets/AppIcon.appiconset/
	xcrun actool build/Assets.xcassets --compile "$(APP)/Contents/Resources" --platform macosx \
		--minimum-deployment-target 14.0 --app-icon AppIcon --output-partial-info-plist build/icon.plist >/dev/null
	codesign --force --options runtime --entitlements TRMNL.entitlements -s "$(SIGN_IDENTITY)" "$(APP)"

test: build
	$(BIN) --selftest

run: build
	open "$(APP)"

install: build
	rm -rf "/Applications/$(APP)"
	cp -R "$(APP)" /Applications/

# Redrawn only when the drawing script changes.
icon/AppIcon-1024.png: icon/make-icon.swift
	mkdir -p build && swiftc -O icon/make-icon.swift -o build/make-icon && build/make-icon $@

# Mac App Store package. Needs TEAM_ID, APPSTORE_IDENTITY, INSTALLER_IDENTITY and PROFILE in local.mk.
appstore: build
	@test -n "$(TEAM_ID)" -a -n "$(APPSTORE_IDENTITY)" -a -n "$(INSTALLER_IDENTITY)" -a -f "$(PROFILE)" \
		|| { echo "Set TEAM_ID, APPSTORE_IDENTITY, INSTALLER_IDENTITY and PROFILE in local.mk (see README)"; exit 1; }
	cp "$(PROFILE)" "$(APP)/Contents/embedded.provisionprofile"
	cp TRMNL.entitlements build/appstore.entitlements
	plutil -insert com.apple.application-identifier -string "$(TEAM_ID).$(BUNDLE_ID)" build/appstore.entitlements
	plutil -insert com.apple.developer.team-identifier -string "$(TEAM_ID)" build/appstore.entitlements
	codesign --force --options runtime --entitlements build/appstore.entitlements -s "$(APPSTORE_IDENTITY)" "$(APP)"
	productbuild --component "$(APP)" /Applications --sign "$(INSTALLER_IDENTITY)" build/MenuBarViewerForTRMNL.pkg
	@echo "Upload build/MenuBarViewerForTRMNL.pkg with the Transporter app."

.PHONY: build test run install appstore
