#!/bin/sh
green='\033[0;32m'
red='\033[0;31m'
nocolor='\033[0m'
deps="meson ninja patchelf unzip curl pip flex bison zip"
workdir="$(pwd)/kgsl_workdir"
ndkver="android-ndk-r25c"
clear



echo "Checking system for required Dependencies ..."
for deps_chk in $deps;
	do 
		sleep 0.25
		if command -v $deps_chk >/dev/null 2>&1 ; then
			echo -e "$green - $deps_chk found $nocolor"
		else
			echo -e "$red - $deps_chk not found, can't countinue. $nocolor"
			deps_missing=1
		fi;
	done
	
	if [ "$deps_missing" == "1" ]
		then echo "Please install missing dependencies" && exit 1
	fi



echo "Installing python Mako dependency (if missing) ..." $'\n'
pip install mako &> /dev/null



echo "Creating and entering to work directory ..." $'\n'
mkdir -p $workdir && cd $workdir



echo "Downloading android-ndk from google server (~506 MB) ..." $'\n'
curl https://dl.google.com/android/repository/"$ndkver"-linux.zip --output "$ndkver"-linux.zip &> /dev/null
###
echo "Exracting android-ndk to a folder ..." $'\n'
unzip "$ndkver"-linux.zip  &> /dev/null



echo "Downloading mesa source (~30 MB) ..." $'\n'
curl https://gitlab.freedesktop.org/MrMiy4mo/mesa/-/archive/freedreno_kgsl/mesa-freedreno_kgsl.zip --output mesa-freedreno_kgsl.zip &> /dev/null
###
echo "Exracting mesa source to a folder ..." $'\n'
unzip mesa-freedreno_kgsl.zip &> /dev/null
cd mesa-freedreno_kgsl



echo "Creating meson cross file ..." $'\n'
ndk="$workdir/$ndkver/toolchains/llvm/prebuilt/linux-x86_64/bin"
cat <<EOF >"android-aarch64"
[binaries]
ar = '$ndk/llvm-ar'
c = ['ccache', '$ndk/aarch64-linux-android29-clang']
cpp = ['ccache', '$ndk/aarch64-linux-android29-clang++', '-fno-exceptions', '-fno-unwind-tables', '-fno-asynchronous-unwind-tables', '-static-libstdc++']
c_ld = 'lld'
cpp_ld = 'lld'
strip = '$ndk/aarch64-linux-android-strip'
pkgconfig = ['env', 'PKG_CONFIG_LIBDIR=$workdir/$ndkver/pkgconfig', '/usr/bin/pkg-config']
[host_machine]
system = 'android'
cpu_family = 'arm'
cpu = 'armv8'
endian = 'little'
EOF



echo "Creating second meson cross file ..." $'\n'
cat <<EOF >"android-aarch64_2"
[binaries]
ar = '$ndk/llvm-ar'
c = ['/usr/bin/gcc']
cpp = ['/usr/bin/g++', '-fno-exceptions', '-fno-unwind-tables', '-fno-asynchronous-unwind-tables', '-static-libstdc++']
c_ld = 'lld'
cpp_ld = 'lld'
strip = '$ndk/aarch64-linux-android-strip'
pkgconfig = ['env', 'PKG_CONFIG_LIBDIR=$workdir/$ndkver/pkgconfig', '/usr/bin/pkg-config']
EOF



echo "Generating build files ..." $'\n'
meson build-android-aarch64 --cross-file $workdir/mesa-freedreno_kgsl/android-aarch64 --native-file $workdir/mesa-freedreno_kgsl/android-aarch64_2 -Dlibdir=$workdir/mesa_kgsl -Dbuildtype=release -Dplatforms=android -Dplatform-sdk-version=29 -Dandroid-stub=true -Dgallium-drivers=freedreno -Dvulkan-drivers= -Dfreedreno-kmds=kgsl -Degl=enabled -Ddri-search-path="/vendor/lib64/egl" --prefix=$workdir/mesa_kgsl -Db_lto=true



echo "Compiling build files ..." $'\n'
ninja -C build-android-aarch64 install



echo "Packing files in to zip archive ..." $'\n'
zip -r $workdir/mesa_kgsl.zip $workdir/mesa_kgsl/* &> /dev/null
