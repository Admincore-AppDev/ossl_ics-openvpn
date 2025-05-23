# ossl_ics-openvpn
This script is inspired from [platform_external_openssl](https://github.com/schwabe/platform_external_openssl "platform_external_openssl") by [Arne Schwabe](https://github.com/schwabe "Arne Schwabe") for [ics-openvpn](https://github.com/schwabe/ics-openvpn "ics-openvpn") and works with **OpenSSL 3.0 and greater.**

Supported Android-Targets: **arm | arm64 | x86 | x86_64**

Supported CMake Lib-Types: **STATIC | SHARED**

This script is refactored and reduced to its minimum, using only some parts of its origin. The goal was to automate the necessary steps to create a prepared OpenSSL-Source which can be used in ics-openvpn CMake-Buildsystem. The adopted original script by Arne Schwabe is completely static and has to adapted with each Major OpenSSL-Update to keep working. Downgrade or Upgrade isn't possible without mandatory changes in the original files like [import_openssl.sh] or [openssl.cmake] - this is a big downside for maintenance. With my script it's possible to use shared libtype in [CMakeLists.txt](https://github.com/schwabe/ics-openvpn/blob/9aee9b529a67cbc03dc10f9484d915b3440a2e81/main/src/main/cpp/CMakeLists.txt#L22 "CMakeLists.txt") to reduce the APK-Size significantly, in tests up to 50% downsizing is possible (Universal-APK).

### Main functions:

* Use the official OpenSSL Git-Repo
* Alternative use of \*.tar.gz Archives from Path or Web
* Search for necessary \*.c files in Makefile
* Read CPP/C-Flags from Makefile
* Read ASM Compiler-Flags from configdata.pm
* Create Assembler-Code (Perl-ASM)
* Expand \*.in to .c/.h/.inc files
* Apply patches from Patch-Folder
* Create openssl.cmake for ics-openvpn (Automatic)

## Usage (Interactive):
	./generate.sh

## Usage (Tar/Web-Method):
	./generate.sh </path/to/openssl-*.tar.gz>
	./generate.sh <https://url/to/openssl-*.tar.gz>

## Quick use:

##### Tags:

	./generate.sh 3.x.x

Valid Tags: https://github.com/openssl/openssl/tags

##### Branches:

	./generate.sh 3.x

Valid Branches: https://github.com/openssl/openssl/branches

##### Or just "master" for the OpenSSL Dev-Branch:

	./generate.sh master
