#!/bin/bash
## Exit on error and warning
set -e
trap "echo WARNING: Exiting on non-zero subprocess exit code" ERR
## Ensure consistent sorting
export LC_ALL=C
export LC_MESSAGES=C
export LANG=C

## Define SDK/API-Level for Android-NDK
ndk_toolchain_sdkint=28

## Config_Args for OpenSSL 3.0 and greater
## Use '#' to comment out specific args
## "no-module" is mandatory for static Legacy-Provider (DONT-REMOVE!)
## "no-engine" means all engines e.g. "afalgeng, capieng and padlockeng"
## Android can't use engines at all
config_args='
-DL_ENDIAN
-D__ANDROID_API__='$ndk_toolchain_sdkint'
#no-asm
no-camellia
no-cast
no-cmp
no-dtls
no-engine
no-gost
no-idea
no-mdc2
no-module
no-rdrand
no-rfc3779
no-rmd160
no-seed
no-ts
no-whirlpool'
## Config_Args for OpenSSL 3.2 and greater
config_args_32x='
no-apps
no-docs
no-sm2-precomp'

## Check for necessary progs
skip_webmode=0
perl_exe='/usr/bin/perl'
[ ! -x "$perl_exe" ] && perl_exe="$(which perl)"
[ ! -x "$perl_exe" ] && echo 'Perl not found - abort!' && exit 1
curl_exe='/usr/bin/curl'
[ ! -x "$curl_exe" ] && curl_exe="$(which curl)"
[ ! -x "$curl_exe" ] && echo 'Curl not found - skip!' && ((skip_webmode++))
wget_exe='/usr/bin/wget'
[ ! -x "$wget_exe" ] && wget_exe="$(which wget)"
[ ! -x "$wget_exe" ] && echo 'Wget not found - skip!' && ((skip_webmode++))
## Check if Android-NDK is proper configurated
[ -d "$ANDROID_NDK_ROOT" ] && ndk_toolchain_path=${ANDROID_NDK_ROOT}/toolchains/llvm/prebuilt/
[ -d "${ndk_toolchain_path}/darwin-x86_64" ] && ndk_toolchain_path+=darwin-x86_64
[ -d "${ndk_toolchain_path}/linux-x86_64" ] && ndk_toolchain_path+=linux-x86_64
[ -d "${ndk_toolchain_path}/windows-x86_64" ] && ndk_toolchain_path+=windows-x86_64
if [[ ! -x ${ndk_toolchain_path}/bin/armv7a-linux-androideabi${ndk_toolchain_sdkint}-clang || \
      ! -x ${ndk_toolchain_path}/bin/aarch64-linux-android${ndk_toolchain_sdkint}-clang || \
      ! -x ${ndk_toolchain_path}/bin/i686-linux-android${ndk_toolchain_sdkint}-clang || \
      ! -x ${ndk_toolchain_path}/bin/x86_64-linux-android${ndk_toolchain_sdkint}-clang ]]
then echo '$ANDROID_NDK_ROOT is not set to a valid directory - abort!' && exit 1; fi
echo -e "Full Android-NDK Toolchain-Path: $ndk_toolchain_path\n\n"

function gen_cmakecnf () {
## Generate CMake-File for ics-openvpn
echo 'Generating openssl.cmake'
cat > ../openssl.cmake <<EOF
enable_language(C ASM)

#################### CRYPTO Library ####################

set(libcrypto_srcs
$libcrypto_srcs
)

if (\${ANDROID_ABI} STREQUAL "armeabi-v7a")
	set(libcrypto_srcs \${libcrypto_srcs}
$arm_libcrypto_asm
	)
	list(REMOVE_ITEM libcrypto_srcs
$(echo "$arm_libcrypto_srcs" | awk '{print "\t" $0}')
	)
elseif (\${ANDROID_ABI} STREQUAL "arm64-v8a")
	set(libcrypto_srcs \${libcrypto_srcs}
$arm64_libcrypto_asm
	)
	list(REMOVE_ITEM libcrypto_srcs
$(echo "$arm64_libcrypto_srcs" | awk '{print "\t" $0}')
	)
elseif (\${ANDROID_ABI} STREQUAL "x86")
	set(libcrypto_srcs \${libcrypto_srcs}
$x86_libcrypto_asm
	)
	list(REMOVE_ITEM libcrypto_srcs
$(echo "$x86_libcrypto_srcs" | awk '{print "\t" $0}')
	)
elseif (\${ANDROID_ABI} STREQUAL "x86_64")
	set(libcrypto_srcs \${libcrypto_srcs}
$x86_64_libcrypto_asm
	)
	list(REMOVE_ITEM libcrypto_srcs
$(echo "$x86_64_libcrypto_srcs" | awk '{print "\t" $0}')
	)
else ()
	message(FATAL_ERROR "Unknown arch \${ANDROID_ABI} for source files")
endif ()

PREPEND(libcrypto_srcs_with_path \${OPENSSL_PATH} \${libcrypto_srcs})
add_library(crypto \${SSLLIBTYPE} \${libcrypto_srcs_with_path})

target_compile_definitions(crypto PRIVATE -DOPENSSLDIR=\"ssl\" -DENGINESDIR=\"engines-3\" -DMODULESDIR=\"ossl-modules\" $(echo $lib_cppflags))
target_compile_options(crypto PRIVATE -Wno-missing-field-initializers -Wno-unused-parameter -Wno-atomic-alignment $(echo $lib_cflags))

target_include_directories(crypto PUBLIC
	\${CMAKE_CURRENT_SOURCE_DIR}/openssl
	\${CMAKE_CURRENT_SOURCE_DIR}/openssl/crypto
	\${CMAKE_CURRENT_SOURCE_DIR}/openssl/include
	\${CMAKE_CURRENT_SOURCE_DIR}/openssl/providers/common/include
	\${CMAKE_CURRENT_SOURCE_DIR}/openssl/providers/fips/include
	\${CMAKE_CURRENT_SOURCE_DIR}/openssl/providers/implementations/include
)

if (\${ANDROID_ABI} STREQUAL "armeabi-v7a")
	target_compile_definitions(crypto PRIVATE
$(echo "$arm_flags" | awk '{print "\t\t" $0}')
	)
elseif (\${ANDROID_ABI} STREQUAL "arm64-v8a")
	target_compile_definitions(crypto PRIVATE
$(echo "$arm64_flags" | awk '{print "\t\t" $0}')
	)
elseif (\${ANDROID_ABI} STREQUAL "x86")
	target_compile_definitions(crypto PRIVATE
$(echo "$x86_flags" | awk '{print "\t\t" $0}')
	)
elseif (\${ANDROID_ABI} STREQUAL "x86_64")
	target_compile_definitions(crypto PRIVATE
$(echo "$x86_64_flags" | awk '{print "\t\t" $0}')
	)
else ()
	message(FATAL_ERROR "Unknown arch \${ANDROID_ABI} for flags")
endif ()

#################### SSL Library ####################

set(libssl_srcs
$libssl_srcs
)

PREPEND(libssl_srcs_with_path \${OPENSSL_PATH} \${libssl_srcs})
add_library(ssl \${SSLLIBTYPE} \${libssl_srcs_with_path})

target_compile_definitions(ssl PRIVATE $(echo $lib_cppflags))
target_compile_options(ssl PRIVATE $(echo $lib_cflags))

target_link_libraries(ssl crypto)

#MESSAGE(FATAL_ERROR "ASM is \${CMAKE_ASM_SOURCE_FILE_EXTENSIONS} and \${CMAKE_CXX_SOURCE_FILE_EXTENSIONS}")
EOF
}

function gen_osslcnf () {
  echo 'Generating configuration.h'
  (
  echo "// Auto-generated - DO NOT EDIT!"
  echo "#if defined(__LP64__)"
  echo "#include \"configuration-64.h\""
  echo "#else"
  echo "#include \"configuration-32.h\""
  echo "#endif"
  ) > include/openssl/configuration.h

  echo 'Generating bn_conf.h'
  (
  echo "// Auto-generated - DO NOT EDIT!"
  echo "#if defined(__LP64__)"
  echo "#include \"bn_conf-64.h\""
  echo "#else"
  echo "#include \"bn_conf-32.h\""
  echo "#endif"
  ) > include/crypto/bn_conf.h

  echo 'Generating buildinf.h'
  (
  echo "// Auto-generated - DO NOT EDIT!"
  echo "#if defined(__LP64__)"
  echo "#include \"buildinf-64.h\""
  echo "#else"
  echo "#include \"buildinf-32.h\""
  echo "#endif"
  ) > crypto/buildinf.h
}

function func_verbose () {
  echo Running: $@
  $@
}

function func_usage () {
  declare -r message=$1
  [ -n "$message" ] && echo "  $message"
  echo -e "\n  Usage:

  [Git-Mode]
  (interactive) ./generate.sh

  [Git-Mode]    ./generate.sh <version e.g. 3.x.x, 3.x or master>

  [Tar-Mode]    ./generate.sh </path/to/openssl-*.tar.gz>

  [Web-Mode]    ./generate.sh <https://url/to/openssl-*.tar.gz>\n"
  exit 1
}

function gen_asm () {
  ## Generate Perlasm-Code with Make
  local gen_asm_in="$tmp_libcrypto_asm"
  local gen_asm_out
  echo -e "\nGenerating ${target}_Assembler ...\n"
  for gen_asm_out in $gen_asm_in; do
    make $gen_asm_out
    if [ -n "$(echo $gen_asm_out | grep 'armx')" ]; then
      echo -e "\nMove $gen_asm_out ...\n"
      mv -f "$gen_asm_out" "$(echo $gen_asm_out | awk '{gsub(/armx/,"armx_'$bits'"); print}')"
    fi
  done
}

function make_in_files () {
  ## Search in OpenSSL-Source to find *.in files and expand them with Make
  if [ "$target" = "arm" ]; then
    local make_in_files_in=$(find crypto include providers ssl -name '*.in' | awk '{gsub(/\.in/, ""); print}' | sort -u)
    local make_in_files_out
    echo -e "\nFound *.in files:\n\n$make_in_files_in\n"
    for make_in_files_out in $make_in_files_in; do make $make_in_files_out || true; done
  fi
  make crypto/buildinf.h
  make include/crypto/bn_conf.h
  make include/openssl/configuration.h
  mv -f crypto/buildinf.h crypto/buildinf-$bits.h
  mv -f include/crypto/bn_conf.h include/crypto/bn_conf-$bits.h
  mv -f include/openssl/configuration.h include/openssl/configuration-$bits.h
}

function parse_c_args () {
  ## Parse Makefile to get recent C/CPP-Flags for CMake
  local parse_c_args_in=$1
  cat Makefile | \
  awk '/'$parse_c_args_in'/ {
    for(i=1; i<=NF; i++) {
      if($i !~ /-D.*DIR=/ && $i !~ /\$\(/ && $i !~ /-D__.*=/) {
        gsub(/.*FLAGS=/, "", $i);
        print $i;
        }
      }
    }'
  # | awk '{ line = line $0 " " } END { sub(/ $/, "", line); print line }'
}

function func_git () {
  ## Clone/Pull OpenSSL Git-Repo
  if [ ! -d "openssl_git" ]; then
    echo -e "\nCloning OpenSSL-Repo ...\n"
    git clone https://github.com/openssl/openssl.git openssl_git
    cd openssl_git
  else
    cd openssl_git
    local actual_tag_branch=$(git describe --all | awk -F'/' '{print $2}')
    echo -e "\nReset OpenSSL-Repo and purge leftover files ...\n"
    git reset --hard
    git clean -fdx
  fi
  ## Determine user input and change input to valid Tags or Branches
  if [ -n "$1" ]; then
    [ -n "$(echo $1 | grep 'openssl-')" ] && ossl_version=$1
    [ -z "$(echo $1 | grep 'openssl-')" ] && ossl_version=openssl-$1
    [[ $1 = openssl-master || $1 = master ]] && ossl_version=master
  else
    echo -e "\n\n    Please enter a valid OpenSSL Tag/Branch

    Tags looks like:     openssl-X.X.X
    Valid Tags:          https://github.com/openssl/openssl/tags

    Branches looks like: openssl-X.X
    Valid Branches:      https://github.com/openssl/openssl/branches

    Type \"master\" for the default Dev-Branch

    If nothing is typed, we use the last Tag/Branch: $actual_tag_branch\n"
    read -p '    openssl-' ossl_version
    [ -n "$ossl_version" ] && ossl_version=openssl-$ossl_version
    [ -z "$ossl_version" ] && ossl_version=$actual_tag_branch
    [ "$ossl_version" = "openssl-master" ] && ossl_version='master'
  fi
  ## I assume it's the best to switch to "master" first to get recent changes from Repo
  echo -e "\nCheckout \"master\" and Pull recent changes from OpenSSL-Repo ...\n"
  git checkout master && git pull
  ## Switch to Tag/Branch
  echo -e "\nCheckout \"$ossl_version\" and Pull recent changes from OpenSSL-Repo ...\n"
  git branch -D $ossl_version > /dev/null 2>&1 || true
  git checkout $ossl_version
  git pull || true
}

function func_tar () {
  ossl_version=$(echo $1 | grep -oE 'openssl-[0-9]+\.[0-9]+\.[0-9]+' | head -n 1)
  if [ -n "$(echo $1 | grep 'http:\|https:')" ]; then
    echo "Downloading OpenSSL, using Web-Method ..."
    [ "$skip_webmode" = "0" ] && $curl_exe -s -L -O -J $1
    [ "$skip_webmode" = "1" ] && $wget_exe -q $1
    [ "$skip_webmode" = "2" ] && echo "Wget nor Curl installed, please download OpenSSL manually and use the Path instead - abort!" && exit 1
    local tar_file=${ossl_version}.tar.gz
  else
    local tar_file=$(echo $1)
  fi
  [ ! -e "$tar_file" ] && echo "Tar-file not found - abort!" && exit 1
  echo "Extracting OpenSSL from Tar-file ..."
  tar -xzf $tar_file
  rm -rf ${ossl_version}.tar.gz openssl_tar
  mv -f $ossl_version openssl_tar
  cd openssl_tar
}

function func_patch () {
  ## Try to apply patches (a little hackish!)
  echo -e "\nApply Patches from Patch-Folder ...\n"
  local patch
  for patch in $(ls -1 ../patch/); do
    local patch_info=$(cat ../patch/$patch | grep 'Subject:' | awk -F'Subject: ' '{print $2}' || true)
    local patch_stdout=$(patch --dry-run -f -s -p1  < ../patch/$patch && patch -f -s -p1 < ../patch/$patch || true)
    if [ -z "$(echo $patch_stdout | grep 'FAILED')" ]; then
      echo -e "Applied Patch: \"$patch_info\"\n"
    else
      echo -e "Skipped Patch: \"$patch_info\"\n"
    fi
done
}

## Check which mode is used, git or tar
if [[ -n $(echo $1 | grep '.tar.gz$') ]]; then
	func_tar $1
elif [[ -z $1 || -n $(echo $1 | grep 'master') || -n $(echo $1 | grep -E '[0-9]+\.[0-9]+$') ]]; then
	func_git $1
else
	func_usage "Invalid input: $1"
fi

## Apply Patches
func_patch

## Apply Config_Args for OpenSSL-3.2 and greater
[ -n "$(echo $ossl_version | grep -v 'openssl-3.0\|openssl-3.1')" ] && config_args+=$config_args_32x

## Main Loop for CMake–Targets
for target in arm arm64 x86 x86_64; do
	func_verbose ./Configure $(echo "$config_args" | grep -v '#.*') $([ "$target" = "arm" ] && echo '-D__ARM_MAX_ARCH__=8') android-$target

	tmp_flags="-D$($perl_exe -we 'use FindBin 1.51 qw( $RealBin );use lib $RealBin;use configdata; print join("\n-D", @{$unified_info{defines}{libcrypto}})')"
	tmp_makefile=$(cat Makefile | grep '\.o:' | grep -v '_win')
	tmp_libcrypto_srcs=$(echo "$tmp_makefile" | grep 'libdefault-\|libcommon-\|libcrypto-\|liblegacy-\|libtemplate-' | awk '{print "\t" $2}' | grep '\.c$' | sort -u)
	tmp_libcrypto_asm=$(echo "$tmp_makefile" | grep 'crypto\/' | awk '{print "\t\t" $2}' | grep '\.S$\|\.s$' | sort -u)

	if [ "$target" = "arm" ]; then
		bits=32
		arm_flags=$(echo -e "$tmp_flags\n-D__ARM_MAX_ARCH__=8")
		arm_libcrypto_asm=$(echo "$tmp_libcrypto_asm" | awk '{gsub(/armx/,"armx_32"); print}')
		libssl_srcs=$(echo "$tmp_makefile" | grep 'libssl-' | awk '{print "\t" $2}' | grep '\.c$' | sort -u)
		make_in_files
	elif [ "$target" = "arm64" ]; then
		bits=64
		arm64_flags=$tmp_flags
		arm64_libcrypto_asm=$(echo "$tmp_libcrypto_asm" | awk '{gsub(/armx/,"armx_64"); print}')
		make_in_files
		lib_cppflags=$(parse_c_args '^CPPFLAGS=|^CNF_CPPFLAGS=|^LIB_CPPFLAGS=')
		lib_cflags=$(parse_c_args '^CFLAGS=|^CNF_CFLAGS=|^LIB_CFLAGS=')
	elif [ "$target" = "x86" ]; then
		x86_flags=$tmp_flags
		x86_libcrypto_asm=$tmp_libcrypto_asm
	elif [ "$target" = "x86_64" ]; then
		x86_64_flags=$tmp_flags
		x86_64_libcrypto_asm=$tmp_libcrypto_asm
	fi

	gen_asm

	mv -f configdata.pm Makefile $(mkdir -p ../info/$target && echo ../info/$target)/.
	echo "$tmp_libcrypto_srcs" > ../info/$target/diff_libcrypto_$target

	echo
done

## Get all *.c files in one file and parse diffs for the CMake ABI-Targets
cat ../info/arm/diff_libcrypto_arm ../info/arm64/diff_libcrypto_arm64 ../info/x86/diff_libcrypto_x86 ../info/x86_64/diff_libcrypto_x86_64 | sort -u > ../info/diff_libcrypto_all
libcrypto_srcs=$(cat ../info/diff_libcrypto_all)
arm_libcrypto_srcs=$(grep -vf ../info/arm/diff_libcrypto_arm ../info/diff_libcrypto_all || true)
arm64_libcrypto_srcs=$(grep -vf ../info/arm64/diff_libcrypto_arm64 ../info/diff_libcrypto_all || true)
x86_libcrypto_srcs=$(grep -vf ../info/x86/diff_libcrypto_x86 ../info/diff_libcrypto_all || true)
x86_64_libcrypto_srcs=$(grep -vf ../info/x86_64/diff_libcrypto_x86_64 ../info/diff_libcrypto_all || true)

## Generate configs
gen_osslcnf
gen_cmakecnf

## Move CMake necessary folders/files to root dir
for finalize in crypto include providers ssl e_os.h; do
	rm -rf ../$finalize
	[[ -d $finalize || -f $finalize ]] && mv -f $finalize ../.
done

echo -e '\nDone!'
