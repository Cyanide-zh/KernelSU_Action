#!/bin/bash
###########################
#  a kernel build script
###########################

##
#  some color setting
##
cinfo="\x1b[38;2;79;155;250m"
cwarn="\x1b[38;2;255;200;97m"
cerror="\x1b[38;2;240;96;96m"
cno="\x1b[0"
export TZ='Asia/Shanghai'
echo "在""$(date +%Y-%m-%d_%H-%M-%S)""时开始编译" >> $GITHUB_WORKSPACE/Kernel/build_time.txt

echo -e "${cinfo}=============== Setup Some Export ===============${cno}"
# 内核工作目录
export KERNEL_DIR=$(pwd)
# 内核 defconfig 文件
export KERNEL_DEFCONFIG=vendor/combined_defconfig
# 编译临时目录，避免污染根目录
export OUT=out
# anykernel3 目录
export ANYKERNEL3=${KERNEL_DIR}/AnyKernel3
# 内核 zip 刷机包名称
build_date=$(date +%Y-%m-%d)
export KERNEL_ZIP_NAME="KernelSU_instantnoodlep.zip"
# 刷机包打包完成后移动目录
export KERNEL_ZIP_EXPORT="$GITHUB_WORKSPACE/Kernel "
# clang 绝对路径
export CLANG_PATH=$GITHUB_WORKSPACE/Kernel/toolchains/zyc-clang 
export PATH=${CLANG_PATH}/bin:${PATH}
export CLANG_TRIPLE=aarch64-linux-gnu-
# arch平台，这里时arm64
export ARCH=arm64
export SUBARCH=arm64
# 只使用clang编译需要配置
export LLVM=1
export BUILD_INITRAMFS=1

# 编译时线程指定，默认单线程，可以通过参数指定，比如4线程编译
# ./build.sh 12
TH_COUNT=$(nproc --all) #使用所有线程
if [[ "" != "$1" ]]; then
        TH_NUM=$6
fi

# 编译参数
export DEF_ARGS="O=${OUT} \
                                CC=clang \
                                CXX=clang++ \
                                ARCH=${ARCH} \
                                CROSS_COMPILE=${CLANG_PATH}/bin/aarch64-linux-gnu- \
                                CROSS_COMPILE_ARM32=${CLANG_PATH}/bin/arm-linux-gnueabi- \
                                LD=ld.lld "
export BUILD_ARGS="-j${TH_COUNT} ${DEF_ARGS}" 

echo -e "${cwarn}kernel workspace dir is => ${KERNEL_DIR}"
echo -e "kernel build defonfig is => ${KERNEL_DEFCONFIG}"
echo -e "build tmpdir is => ${KERNEL_DIR}/${OUT}"
echo -e "anykernel3 workspace dir is => ${ANYKERNEL3}"
echo -e "kernel zip name is => ${KERNEL_ZIP_NAME}"
echo -e "kernel zip export dir is => ${KERNEL_ZIP_EXPORT}"
echo -e "clang path is => ${CLANG_PATH}"
echo -e "build arch/subarch is => ${ARCH} / ${SUBARCH}${cno}"
# 等待3s，查看配置文件信息是否正确，不正确 Ctrl + C 及时取消
sleep 3s

echo -e "${cinfo}=============== Make defconfig ===============${cno}"
# make defconfig
make ${DEF_ARGS} ${KERNEL_DEFCONFIG}
# 如果命令没有出错，继续执行，否则退出编译
if [[ "0" != "$?" ]]; then
        echo -e "${cerror}>>> make defconfig error, build stop!${cno}"
        exit 1
fi

echo -e "${cinfo}=============== Make Kernel  ===============${cno}"
make ${BUILD_ARGS}
if [[ "0" != "$?" ]]; then
        echo -e "${cerror}>>> build kernel error, build stop!${cno}"
        exit 1
fi
echo -e "${cwarn}>>> build kernel success${cno}"
sleep 2s
echo "在""$(date +%Y-%m-%d_%H-%M-%S)""时完成编译" >> $GITHUB_WORKSPACE/Kernel/build_time.txt
# 使用 Anykernel3 制作刷机包
echo -e "${cinfo}=============== Make Kernel Zip ==============="
if test -e ${ANYKERNEL3}; then
        if test -e ${KERNEL_DIR}/${OUT}/arch/${ARCH}/boot/dtbo.img; then
                if test -e ${KERNEL_DIR}/${OUT}/arch/${ARCH}/boot/Image.gz-dtb; then
                        echo -e "${cwarn}move kernel files . . .${cno}"
                        cp ${KERNEL_DIR}/${OUT}/arch/${ARCH}/boot/dtbo.img ${ANYKERNEL3}/
                        cp ${KERNEL_DIR}/${OUT}/arch/${ARCH}/boot/Image.gz-dtb ${ANYKERNEL3}/
                        echo -e "${cwarn}into anykernel3 workdir. . ."
                        cd ${ANYKERNEL3}
                        if test -e ./Image.gz-dtb; then
                                zip -r ${KERNEL_ZIP_NAME} ./*
                                test -e ./${KERNEL_ZIP_NAME} && cp ./${KERNEL_ZIP_NAME} ${KERNEL_ZIP_EXPORT}
                                echo -e "${cwarn} clean kernel files. . .${cno}"
                                test -e ./Image.gz-dtb && rm ./Image.gz-dtb
                                test -e ./dtbo.img && rm ./dtbo.img
                        else
                                echo -e "${cerror}stopmake => kernel file not found!${cno}"
                                exit 1
                        fi
                else
                        #echo -e "${cerror}stop make => Image.gz-dtb not found${cno}"
                        #exit 1
                        cp ./out/arch/arm64/boot/Image ./out/arch/arm64/boot/Image.gz-dtb
                fi
        else
                #echo -e "${cerror}stop make => dtbo.img not found${cno}"
                #exit 1
                touch ./out/arch/arm64/boot/dtbo.img
        fi
else
        echo -e "${cerror}stop build => anykernel3 dir not found${cno}"
        exit 1
fi
echo "在""$(date +%Y-%m-%d_%H-%M-%S)""时完成全过程" >> $GITHUB_WORKSPACE/Kernel/build_time.txt
cat $GITHUB_WORKSPACE/Kernel/build_time.txt
ls -lh ${KERNEL_ZIP_EXPORT}
ls -lh ./out/
exit 0
