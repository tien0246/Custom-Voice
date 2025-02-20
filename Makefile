ARCHS = arm64 arm64e
DEBUG = 0
FINALPACKAGE = 1
FOR_RELEASE = 1
IGNORE_WARNINGS = 1
GO_EASY_ON_ME = 1

THEOS_DEVICE_IP = 192.168.137.123
THEOS_DEVICE_PORT = 22

TARGET := iphone:clang:latest:14.0

include $(THEOS)/makefiles/common.mk

TWEAK_NAME = CustomVoice

$(TWEAK_NAME)_CFLAGS = -fobjc-arc -fvisibility=hidden

$(TWEAK_NAME)_CCFLAGS = -std=c++11 -fno-rtti -DNDEBUG -fno-objc-arc

${TWEAK_NAME}_FILES = Tweak.xm fishhook/fishhook.c $(wildcard SettingsView/*.mm)

$(TWEAK_NAME)_FRAMEWORKS = UIKit

$(TWEAK_NAME)_LDFLAGS += -L$(THEOS_PROJECT_DIR)/SoundTouch -lSoundTouch

$(TWEAK_NAME)_CFLAGS += -I$(THEOS_PROJECT_DIR)/SoundTouch/include

include $(THEOS_MAKE_PATH)/tweak.mk

after-install::
	install.exec "killall -9 kgvn"

clean::
	rm -rf .theos
