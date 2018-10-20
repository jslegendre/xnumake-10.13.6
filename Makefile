MACOSX_SDK = MacOSX10.13

PKGS := xnu dtrace AvailabilityVersions libplatform libdispatch Libsystem
xnu_version = 4570.71.2
Libsystem_version = 1252.50.4
libplatform_version = 161.50.1
dtrace_version = 262.50.12
AvailabilityVersions_version = 32.60.1
libdispatch_version = 913.60.2

default: kernel

XCODE_SDKS_DIR := $(shell xcrun -sdk macosx --show-sdk-platform-path)/Developer/SDKs
MACOSX_SDK_SRC := $(XCODE_SDKS_DIR)/$(MACOSX_SDK).sdk
MACOSX_SDK_DST := $(CURDIR)/src/xnu-4570.71.2/$(MACOSX_SDK)-xnu.sdk
MACOSX_SDK_LNK := $(XCODE_SDKS_DIR)/$(shell basename $(MACOSX_SDK_DST))
MACOSX_SDK_XNU := $(shell echo $(MACOSX_SDK) | tr A-Z a-z)-xnu
TOOLCHAIN_PATH=$(shell xcrun -toolchain XcodeDefault -find clang | sed 's,\(.*xctoolchain\)/.*,\1,')
XCODEPATH=$(shell xcrun -sdk macosx -show-sdk-path | sed 's,\(.*/Xcode.app\)/.*,\1,')
APPLEOPENSOURCE = https://opensource.apple.com
TARBALL_URL = $(APPLEOPENSOURCE)/tarballs

setup:
	mkdir -p src build src/.tarballs

xnu: 
	patch -s -p1 < patches/if_ipsec.patch
	patch -s -p1 < patches/OSKext.patch
	@echo "--------------------------------------------------"
	@echo "XNU patched!"
	@echo "--------------------------------------------------"

config_sdk: setup xnu 
ifeq ($(shell test -d $(MACOSX_SDK_SRC); echo $$?), 1)
	$(error "The SDK $(MACOSX_SDK) cannot be found, make sure that the latest Xcode version is installed")
endif
	mkdir -p $(MACOSX_SDK_DST)
	cd $(MACOSX_SDK_SRC) && rsync -rtpl . $(MACOSX_SDK_DST)
	plutil -replace CanonicalName -string $(MACOSX_SDK_XNU) $(MACOSX_SDK_DST)/SDKSettings.plist
	rm -f $(MACOSX_SDK_LNK)

sdk: config_sdk dtrace AvailabilityVersions libdispatch
	@echo
	@echo "--------------------------------------------------"
	@echo "SDK configured successfully!"
	@echo "It is located at: src/$(xnu_src)/$(MACOSX_SDK)-xnu.sdk"
	@echo "--------------------------------------------------"
	@echo

install_sdk:
	cp -R $(MACOSX_SDK_DST) $(XCODE_SDKS_DIR)

dtrace:
	@$(HELP) mkdir -p $(dtrace_build)/obj $(dtrace_build)/sym $(dtrace_build)/dst
	@$(HELP) cd $(SRCDIR) && $(HELP) xcodebuild install -target ctfconvert -target ctfdump -target ctfmerge ARCHS="x86_64" SRCROOT="$(SRCDIR)" OBJROOT="$(dtrace_build)/obj" SYMROOT="$(dtrace_build)/sym" DSTROOT="$(dtrace_build)/dst"
	@$(HELP) sudo ditto "$(dtrace_build)/dst/$(XCODEPATH)/Contents/Developer/Toolchains/XcodeDefault.xctoolchain" "$(TOOLCHAIN_PATH)"

AvailabilityVersions:
	@$(HELP) mkdir -p "$(AvailabilityVersions_build)/dst"
	@$(HELP) make -C $(SRCDIR) install SRCROOT="$(SRCDIR)" DSTROOT="$(AvailabilityVersions_build)/dst"
	@$(HELP) sudo ditto "$(AvailabilityVersions_build)/dst/usr/local/libexec" "$(MACOSX_SDK_DST)/usr/local/libexec"
	
libplatform: INTPATH = usr/local/include/os/internal
libplatform:
	@$(HELP) sudo mkdir -p "$(MACOSX_SDK_DST)/$(INTPATH)"
	@$(HELP) sudo ditto $(SRCDIR)/private/os/internal "$(MACOSX_SDK_DST)/$(INTPATH)"

libdispatch: libplatform
	@$(HELP) cd $(xnu_path) && $(HELP) make XNU_LOGCOLORS=y SDKROOT=$(MACOSX_SDK_DST) OBJROOT="$(xnu_build)/obj" SYMROOT="$(xnu_build)/sym" DSTROOT="$(xnu_build)/dst" ARCH_CONFIGS=X86_64 installhdrs
	@$(HELP) sudo ditto "$(xnu_build)/dst" "$(MACOSX_SDK_DST)"
	@$(HELP) cd $(SRCDIR) && $(HELP) xcodebuild install -sdk $(MACOSX_SDK_DST) -target libfirehose_kernel SRCROOT="$(SRCDIR)" OBJROOT="$(libdispatch_build)/obj" SYMROOT="$(libdispatch_build)/sym" DSTROOT="$(libdispatch_build)/dst"
	@$(HELP) sudo ditto "$(libdispatch_build)/dst/usr/local" "$(MACOSX_SDK_DST)/usr/local"

build_xnu:
	make -C $(xnu_path) OBJROOT="$(xnu_build)/obj" SYMROOT="$(xnu_build)/sym" DSTROOT="$(xnu_build)/dst" SDKROOT=$(MACOSX_SDK_DST) XNU_LOGCOLORS=y ARCH_CONFIGS=X86_64 KERNEL_CONFIGS=RELEASE
	@echo
	@echo "--------------------------------------------------"
	@echo "XNU built!"
	@echo "--------------------------------------------------"
	@echo

all: sdk build_xnu

define download_tarball
$(1)_tarball := $(1)-$$($(1)_version).tar.gz
$(1)_src := $(1)-$$($(1)_version)
$(1)_path := $(PWD)/src/$(1)-$$($(1)_version)
$(1)_build := $(PWD)/build/$(1)-$$($(1)_version)
$$($(1)_tarball):
	@echo "Downloading $(1)..."
	@$$(HELP) curl $$(TARBALL_URL)/$(1)/$(1)-$$($(1)_version).tar.gz -o src/.tarballs/$(1)-$$($(1)_version).tar.gz
$$($(1)_src)/.src: $$($(1)_tarball)
	@echo "Unpacking $(1)..."
	@$$(HELP) tar zxf src/.tarballs/$$< -C src/
$(1): $$($(1)_src)/.src
$(1): SRCDIR=$$(shell pwd)/src/$(1)-$$($(1)_version)
endef

$(foreach pkg,$(PKGS),$(eval $(call download_tarball,$(pkg))))

clean: 
	sudo rm -rf build
	sudo rm -rf src