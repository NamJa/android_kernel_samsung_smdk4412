#!/bin/bash

TARGET=$1
if [ "$TARGET" != "" ]; then
	echo "starting your build for $TARGET"
else
	echo ""
	echo "you need to define your device target!"
	echo "example: build_sammy.sh n7100"
	exit 1
fi

if [ "$TARGET" = "i9300" ] ; then
CUSTOM_PATH=i9300
MODE=DUAL
else
CUSTOM_PATH=note
MODE=DUAL
fi

displayversion=3G_Devil3.4_0.1.2
version=$displayversion-$TARGET-$MODE-$(date +%Y%m%d)

if [ -e boot.img ]; then
	rm boot.img
fi

if [ -e compile.log ]; then
	rm compile.log
fi

if [ -e ramdisk.cpio ]; then
	rm ramdisk.cpio
fi

if [ -e ramdisk.cpio.lzma ]; then
	rm ramdisk.cpio.lzma
fi

# Set Default Path
KERNEL_PATH=$PWD

# Set toolchain and root filesystem path
TOOLCHAIN_PATH="/opt/linaro-arm-eabi-4.9/bin"
TOOLCHAIN="$TOOLCHAIN_PATH/arm-eabi-"
ROOTFS_PATH="$KERNEL_PATH/ramdisks-3g/$TARGET-combo"

defconfig=cyanogenmod_"$TARGET"_defconfig

export LOCALVERSION="-$displayversion"
export KERNELDIR=$KERNEL_PATH
export CROSS_COMPILE=$TOOLCHAIN
export ARCH=arm

export USE_SEC_FIPS_MODE=true

# Set ramdisk files permissions
cd $ROOTFS_PATH
ls $ROOTFS_PATH/roms/ | while read ramdisk; do
	cd $ROOTFS_PATH/roms/$ramdisk
	echo fixing permisions on $(pwd)
chmod 644 *.rc
chmod 750 init*
chmod 640 fstab*
chmod 644 default.prop
done
chmod 750 $ROOTFS_PATH/sbin/init*
chmod a+x $ROOTFS_PATH/sbin/*.sh
cd $KERNEL_PATH

if [ "$2" = "clean" ]; then
echo "Cleaning latest build"
make -j`grep 'processor' /proc/cpuinfo | wc -l` mrproper
fi
# Cleaning old kernel and modules
find -name '*.ko' -exec rm -rf {} \;
rm -rf $KERNEL_PATH/arch/arm/boot/zImage

# Making our .config
make $defconfig

scripts/configcleaner "
CONFIG_WLAN_REGION_CODE
CONFIG_TARGET_LOCALE_EUR
CONFIG_TARGET_LOCALE_USA
CONFIG_TARGET_LOCALE_KOR
CONFIG_MACH_M0_KOR_SKT
CONFIG_MACH_M0_KOR_KT
CONFIG_MACH_M0_KOR_LGT
"
echo "
CONFIG_WLAN_REGION_CODE=201
# CONFIG_TARGET_LOCALE_EUR is not set
# CONFIG_TARGET_LOCALE_USA is not set
CONFIG_TARGET_LOCALE_KOR=y
CONFIG_MACH_M0_KOR_SKT=y
# CONFIG_MACH_M0_KOR_KT is not set
# CONFIG_MACH_M0_KOR_LGT is not set
" >> .config

make -j`grep 'processor' /proc/cpuinfo | wc -l` || exit -1
# Copying and stripping kernel modules
mkdir -p $ROOTFS_PATH/lib/modules
find -name '*.ko' -exec cp -av {} $ROOTFS_PATH/lib/modules/ \;
        "$TOOLCHAIN"strip --strip-unneeded $ROOTFS_PATH/lib/modules/*

# Copy Kernel Image
rm -f $KERNEL_PATH/releasetools-ckh469/$CUSTOM_PATH/zip/$version.zip
cp -f $KERNEL_PATH/arch/arm/boot/zImage .


# Create ramdisk.cpio archive
cd $ROOTFS_PATH
find . | fakeroot cpio -o -H newc > $KERNEL_PATH/ramdisk.cpio 2>/dev/null
ls -lh $KERNEL_PATH/ramdisk.cpio
lzma -9 $KERNEL_PATH/ramdisk.cpio
cd $KERNEL_PATH

# Make boot.img
./mkbootimg --kernel zImage --ramdisk ramdisk.cpio.lzma --board smdk4x12 --base 0x10000000 --pagesize 2048 --ramdiskaddr 0x11000000 -o $KERNEL_PATH/boot.img

# Copy boot.img
cp boot.img $KERNEL_PATH/releasetools-ckh469/$CUSTOM_PATH/zip

# Creating flashable zip and tar
cd $KERNEL_PATH
cd releasetools-ckh469/$CUSTOM_PATH/zip
zip -0 -r $version.zip *
mkdir -p $KERNEL_PATH/release
mv *.zip $KERNEL_PATH/release

# Cleanup
cd $KERNEL_PATH
rm $KERNEL_PATH/releasetools-ckh469/$CUSTOM_PATH/zip/boot.img
rm $KERNEL_PATH/zImage
