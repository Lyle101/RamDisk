#!/usr/bin/env sh

# 设置内存盘的名称
DISK_NAME=RamDisk
MOUNT_PATH=/Volumes/$DISK_NAME

# 设置备份文件的保存路径
WORK_PATH=/etc/ramdisk
BAK_PATH=$WORK_PATH/$DISK_NAME.tar.gz

# 设置RamDisk日志文件
LOG=$WORK_PATH/init_ramdisk_log.txt

# 设置分配给内存盘的空间大小(MB) 这是上限值，一般情况下使用多少占多少的内存
DISK_SPACE=1024

# 创建Ramdisk
if [ ! -e $MOUNT_PATH ]; then
    echo "["`date`"]" "Create ramdisk..." > $LOG
    RAMDISK_SECTORS=$(($DISK_SPACE*1024*2))
    DISK_ID=$(hdiutil attach -nomount ram://$RAMDISK_SECTORS)
    echo "["`date`"]" "Disk ID is :" $DISK_ID | tee -a $LOG
    diskutil erasevolume HFS+ $DISK_NAME ${DISK_ID} | tee -a $LOG
elif [[ $1 == "umount" ]]; then
    echo "Delete/unmount ramdisk $MOUNT_PATH"
    hdiutil detach $MOUNT_PATH || umount -f $MOUNT_PATH
    exit
fi

# 隐藏分区
chflags hidden $MOUNT_PATH

# 恢复备份
if [ -s $BAK_PATH ]; then
    echo "["`date`"]" "Restoring BAK Files ..." | tee -a $LOG
    tar -zxvf $BAK_PATH -C $MOUNT_PATH 2>&1 | tee -a $LOG
fi

# 设置要创建的文件夹
Dirs="
/Volumes/Ramdisk/Caches/Google
/Volumes/Ramdisk/Caches/com.apple.Safari
/Volumes/Ramdisk/Caches/Xcode
/Volumes/RamDisk/Caches/NeteaseMusic
/Volumes/RamDisk/RamDownloads
"
# 如果文件夹不存在，则创建相应的文件夹
for Dir in $Dirs; do
    if [ ! -d "$Dir" ]; then
        echo "["`date`"]" "Making Directory: $Dir" | tee -a $LOG
        mkdir -p "$Dir"
    fi
done


HOME="/Users/charles"

Links="
$HOME/Library/Caches/Google
$HOME/Library/Caches/com.apple.Safari
"
# 如果链接不存在，则创建相应的软连接
for Link in $Links; do
    Dir_Name=${Link##*/}
    if [ ! -L "$Link" ]; then
        if [ -d "$Link" ]; then
            echo "\nMove & Delete Dir:" | tee -a $LOG
            mv -v $Link/* /Volumes/Ramdisk/Caches/$Dir_Name/ | tee -a $LOG
            rm -rfv "$Link" | tee -a $LOG
        fi
    echo "\nCreate soft link:" | tee -a $LOG
    ln -sv /Volumes/Ramdisk/Caches/$Dir_Name $Link | tee -a $LOG
    fi
done

