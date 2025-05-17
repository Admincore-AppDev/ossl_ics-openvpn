# OSSL_ICS-OPENVPN
This script is inspired by [platform_external_openssl](https://github.com/schwabe/platform_external_openssl "platform_external_openssl") by [Arne Schwabe](https://github.com/schwabe "Arne Schwabe") for [ics-openvpn](https://github.com/schwabe/ics-openvpn "ics-openvpn") and works with **OpenSSL 3.0 and greater.**

#### Supported targets: arm | arm64 | x86 | x86_64

This script is refactored and break down to the minimum, using only some parts of its origin. The goal was to automate the necessary steps to create a prepared OpenSSL source that can be used in CMake. The original script is static and has to be adapted with each OpenSSL update to keep working. Downgrade or upgrade is not possible without mandatory changes in the original files on import_openssl.sh and openssl.cmake.

### Main functions:

* Use the official OpenSSL Git-Repo
* Search for necessary \*.c files
* Translate \*.in files
* Create Assembler-Code (Perl-ASM)
* Apply patches from patch-folder
* Create openssl.cmake

Just type:

	git clone https://github.com/Admincore-AppDev/ossl_ics-openvpn
	cd ossl_ics-openvpn
	./generate.sh

That's it, follow the instructions to choose the desired OpenSSL-Version and let the script doing it's magic. If config_args are in conflict with older OpenSSL-Version's just remove them from generate.sh.

To get a prebuilt source which is already ready, just type:

	git clone -b openssl-3.5 https://github.com/Admincore-AppDev/ossl_ics-openvpn

for the most recent avaiable OpenSSL-Version.

Checkout: https://github.com/Admincore-AppDev/ossl_ics-openvpn/branches for more active branches.
