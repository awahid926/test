#!/bin/bash

if [ $OS = "ecos" ];then
BUILD_TEMP_DIR=${GXSRC_PATH}/output/image/bin_ecos

# delete temp file
#rm -rf $BUILD_TEMP_DIR
#
mkdir -p $BUILD_TEMP_DIR

#copy files
cp ${GXSRC_PATH}/output/out.elf ${BUILD_TEMP_DIR}

cp -rf ${GXSRC_PATH}/system/ecos_template/flash/file_img/datafs_ecos ${BUILD_TEMP_DIR}
cp -rf ${GXSRC_PATH}/system/ecos_template/flash/file_img/rootfs_ecos ${BUILD_TEMP_DIR}

mkdir -p ${BUILD_TEMP_DIR}/rootfs_ecos/dvb

# choose the right theme
rm -rf ${BUILD_TEMP_DIR}/rootfs_ecos/dvb/theme
HD=$(cat ${GXSRC_PATH}/app/include/app_config.h| grep HD |wc -l)
if [ $HD -eq 1 ]; then
#cp -r ${GXSRC_PATH}/output/theme/HD ${BUILD_TEMP_DIR}/rootfs_ecos/dvb/theme;
cp -r ${GXSRC_PATH}/output/theme/ ${BUILD_TEMP_DIR}/rootfs_ecos/dvb/theme;
else
#cp -r ${GXSRC_PATH}/output/theme/SD ${BUILD_TEMP_DIR}/rootfs_ecos/dvb/theme;
cp -r ${GXSRC_PATH}/output/theme/ ${BUILD_TEMP_DIR}/rootfs_ecos/dvb/theme;
fi;

GAME_OFF=$(cat ${GXSRC_PATH}/app/include/app_config.h| grep "GAME_ENABLE" | grep "0" | wc -l)
if [ $GAME_OFF -eq 1 ]; then
rm ${BUILD_TEMP_DIR}/rootfs_ecos/dvb/theme/image/game -rf;
fi;

#delete useless widget xml
rm ${BUILD_TEMP_DIR}/rootfs_ecos/dvb/theme/widget/win_movie_view_speed_*.xml -rf;

mkdir -p ${BUILD_TEMP_DIR}/ecos

#delete svn file
rm ${BUILD_TEMP_DIR}/rootfs_ecos/dvb/theme/img_index -rf
find ${BUILD_TEMP_DIR} -type d -name ".svn" | xargs rm -rf

#delete Thumbs.db
find ${BUILD_TEMP_DIR} -name "Thumbs.db" | xargs rm -rf

#delete useless language xml
LANG_DIR=${BUILD_TEMP_DIR}/rootfs_ecos/dvb/theme/language
LANG=$(cat ${LANG_DIR}/language | grep '#' | tr -d "#")
LANG_FILE=`find ${LANG_DIR} -name "*.xml"`
for i in $LANG_FILE ; do
	FILE_NAME=$(basename $i .xml)
	EXIST=0
	for j in $LANG; do
	    if [ $FILE_NAME = $j ] || [ $FILE_NAME = "i18n" ]; then
			EXIST=1
		fi;
	done
	if [ $EXIST -eq 0 ]; then
		rm $i -f
	fi
done

#delete script
find ${BUILD_TEMP_DIR} -name "*.sh" | xargs rm -rf
find ${BUILD_TEMP_DIR} -name "*.xls" | xargs rm -rf
find ${BUILD_TEMP_DIR} -name "*.py" | xargs rm -rf

#create ecos_romfs
if [ $ARCH = "arm" ];then
arm-eabi-objcopy ${BUILD_TEMP_DIR}/out.elf -S -g -O binary ${BUILD_TEMP_DIR}/ecos.bin   
else
csky-elf-objcopy ${BUILD_TEMP_DIR}/out.elf -S -g -O binary ${BUILD_TEMP_DIR}/ecos.bin
fi;

gzip ${BUILD_TEMP_DIR}/ecos.bin
mv -f ${BUILD_TEMP_DIR}/ecos.bin.gz ${BUILD_TEMP_DIR}/ecos
genromfs -f ${BUILD_TEMP_DIR}/ecos_romfs.img -d ${BUILD_TEMP_DIR}/ecos/

# write fstab
#CONF=${GXSRC_PATH}/system/ecos_template/flash/flash.conf
CONF=${GXSRC_PATH}/output/image/bin_ecos/flash.conf
BOOT=`cat $CONF | grep "#" -v | grep BOOT -n | awk -F ':' '{print $1}'`
DATA=`cat $CONF | grep "#" -v | grep DATA -n | awk -F ':' '{print $1}'`
printf "/dev/flash/0/%d  /home/gx  minifs\n" $((DATA-BOOT)) >${BUILD_TEMP_DIR}/rootfs_ecos/etc/fstab
printf "NONE  /mnt  ramfs\n" >>${BUILD_TEMP_DIR}/rootfs_ecos/etc/fstab

#create cramfs, fstab changed need build it again
mkfs.cramfs ${BUILD_TEMP_DIR}/rootfs_ecos ${BUILD_TEMP_DIR}/root_cramfs.img

#cp ${BUILD_TEMP_DIR}/ecos_romfs.img ${GXSRC_PATH}/system/ecos_template/flash
#cp ${BUILD_TEMP_DIR}/root_cramfs.img ${GXSRC_PATH}/system/ecos_template/flash

#cd ${GXSRC_PATH}/system/ecos_template/flash

# this files below is copied from each project 

#cp ${GXSRC_PATH}/system/ecos_template/flash/flash.conf ${BUILD_TEMP_DIR}
#cp ${GXSRC_PATH}/system/ecos_template/flash/loader-flash.bin ${BUILD_TEMP_DIR}
#cp ${GXSRC_PATH}/system/ecos_template/flash/logo.bin ${BUILD_TEMP_DIR}
#cp ${GXSRC_PATH}/system/ecos_template/flash/*.ini ${BUILD_TEMP_DIR}

cp ${GXSRC_PATH}/system/ecos_template/flash/minifs.img ${BUILD_TEMP_DIR}

cp ${GXSRC_PATH}/tools/genflash/genflash ${BUILD_TEMP_DIR}

cd ${BUILD_TEMP_DIR}
chmod +x ./genflash
./genflash mkflash flash.conf download.bin

mkdir -p ../../../output/image
mv download.bin ../../../output/image/download_ecos.bin
fi

if [ $OS = "linux" ];then
BUILD_TEMP_DIR=${GXSRC_PATH}/output/image/bin_linux

#rm -rf ${BUILD_TEMP_DIR}
rm -rf ${BUILD_TEMP_DIR}/user/theme

mkdir -p ${BUILD_TEMP_DIR}/user

#cd system/bin_linux
#rm -rf ./user -rf
#mkdir user
cp ${GXSRC_PATH}/output/out.elf ${BUILD_TEMP_DIR}/user/out.elf -f
cp ${GXSRC_PATH}/output/gxdlna ${BUILD_TEMP_DIR}/user/gxdlna -f
cp ${GXSRC_PATH}/output/gdbserver ${BUILD_TEMP_DIR}/user/gdbserver -f
cp  -ar ${GXSRC_PATH}/output/theme ${BUILD_TEMP_DIR}/user/theme

find ${BUILD_TEMP_DIR}/user -type d -name ".svn"|xargs rm -rf
csky-linux-strip ${BUILD_TEMP_DIR}/user/out.elf

cp ${GXSRC_PATH}/tools/genflash/mksquashfs ${BUILD_TEMP_DIR}
cp ${GXSRC_PATH}/tools/genflash/genflash ${BUILD_TEMP_DIR}

#cp ${GXSRC_PATH}/tools/genflash/flash.conf ${BUILD_TEMP_DIR}
#cp ${GXSRC_PATH}/tools/genflash/loader-flash.bin ${BUILD_TEMP_DIR}
#cp ${GXSRC_PATH}/tools/genflash/uImage ${BUILD_TEMP_DIR}
#cp ${GXSRC_PATH}/tools/genflash/rootfs.bin ${BUILD_TEMP_DIR}
#cp ${GXSRC_PATH}/tools/genflash/cfg.bin ${BUILD_TEMP_DIR}

cd ${BUILD_TEMP_DIR}
./mksquashfs user user.bin -noappend -no-duplicates > /dev/null
./genflash mkflash ./flash.conf flashrom.bin
mkdir -p ${GXSRC_PATH}/output/image
mv flashrom.bin ${GXSRC_PATH}/output/image/download_linux.bin
#rm -rf user
fi


