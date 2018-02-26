# RamDisk
虚拟内存盘是通过软件将一部分内存（RAM）模拟为硬盘来使用的一种技术。  由于内存有高达数 GB 每秒的速度，模拟成硬盘在适当情景下使用，会极大的增强系统性能，并且起到保护硬盘和隐私的作用。Mac OS X 是 类Unix 操作系统，原生就支持用`命令行创建Ramdisk`。本项目的目的是创建一个`开机自动创建`的 Ramdisk，并且提供关机自动备份Ram盘的功能。


## 工作流程：

  1. 开机的时候，自动调用initramdisk.sh脚本创建内存盘，然后载入需要的数据。
  2. 关机的时候，自动调用syncramdisk.sh脚本把内存盘数据回写硬盘，然后执行关机。

## 创建RamDisk脚本

在`/etc/`下创建`ramdisk`目录，用来存放相关文件

### initramdisk.sh

创建`/etc/ramdisk/initramdisk.sh`

	vim /etc/ramdisk/initramdisk.sh

```sh
#!/usr/bin/env sh

# 设置内存盘的名称
DISK_NAME=RamDisk
MOUNT_PATH=/Volumes/$DISK_NAME

# 设置备份文件的保存路径
WORK_PATH=/etc/ramdisk
BAK_PATH=$WORK_PATH/$DISK_NAME.tar.gz

# 设置RamDisk日志文件
LOG=$WORK_PATH/RamDisk.log.txt

# 设置分配给内存盘的空间大小(MB) 这是上限值，一般情况下使用多少占多少的内存
DISK_SPACE=1024

# 创建Ramdisk
if [ ! -e $MOUNT_PATH ]; then
    echo "["`date`"]" "Create ramdisk..." | tee $LOG
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
DIRS="
/Volumes/Ramdisk/Caches/Google
/Volumes/Ramdisk/Caches/Safari
/Volumes/Ramdisk/Caches/Xcode
/Volumes/RamDisk/Caches/NeteaseMusic
/Volumes/RamDisk/RamDownloads
"

for Dir in $DIRS; do
    if [ ! -d "$Dir" ]; then
        echo "["`date`"]" "Making Directory: $Dir" | tee -a $LOG
        mkdir -p "$Dir"
    fi
done

```



### syncramdisk.sh

创建`/etc/ramdisk/syncramdisk.sh`

	vim /etc/ramdisk/syncramdisk.sh


```sh
#!/usr/bin/env sh

# 设置内存盘的名称
DISK_NAME=RamDisk
MOUNT_PATH=/Volumes/$DISK_NAME

# 设置备份文件的保存路径
WORK_PATH=/etc/ramdisk
BAK_PATH=$WORK_PATH/$DISK_NAME.tar.gz
LISTFILE=$WORK_PATH/list.txt

# 设置最大的cache大小(MB)
MAX_CACHE_SIZE=50

[ -d $WORK_PATH ] || mkdir $WORK_PATH


rm -rfv /Volumes/RamDisk/Caches/NeteaseMusic/online_play_cache/*

# 备份Ramdisk内容，超过50M的目录直接不再保存
cd $MOUNT_PATH
declare -a fa
i=0
for file in $(du -s Caches/* | sort -n)
do
  fa[$i]=$file
  let i=i+1
done
size=$((i/2))
echo "file number:"$size
cd $WORK_PATH
echo ".?*">$LISTFILE
for((i=0;i<$size;i++))
do
  if ((${fa[$((i*2))]}<(($MAX_CACHE_SIZE*1024*2)) ));then
    echo "add:"${fa[$((i*2+1))]}
  else
    echo ${fa[$((i*2+1))]}>>$LISTFILE
  fi

done
if [ -e $MOUNT_PATH ] ; then
    cd $MOUNT_PATH
    tar --exclude-from $LISTFILE -czf $BAK_PATH .
fi
```

### 设置登录和注销hook

在终端下执行：

```sh
# 登录时执行initramdisk.sh
sudo defaults write com.apple.loginwindow LoginHook /etc/RamDisk/initramdisk.sh

# 注销时执行syncramdisk.sh
sudo defaults write com.apple.loginwindow LogoutHook /etc/RamDisk/syncramdisk.sh

# 查看登录脚本
sudo defaults read com.apple.loginwindow
```

## 迁移目录到RamDisk


### 转移Chrome、Safari、Xcode、网易云音乐等软件缓存

```sh
# 创建内存盘：
sh /etc/ramdisk/syncramdisk.sh

# 在桌面创建内存盘软连接：
ln -s /Volumes/RamDisk ~/Desktop/RamDisk

# 运行以下脚本前请先退出以下软件：Chrome Safari Xcode 网易云音乐
rm -rf ~/Library/Caches/Google
rm -rf ~/Library/Caches/com.apple.Safari
rm -rf ~/Library/Developer/Xcode/DerivedData
rm -rf ~/Library/Containers/com.netease.163music/Data/Caches

ln -s /Volumes/Ramdisk/Caches/Google ~/Library/Caches/Google
ln -s /Volumes/Ramdisk/Caches/Safari ~/Library/Caches/com.apple.Safari
ln -s /Volumes/Ramdisk/Caches/Xcode ~/Library/Developer/Xcode/DerivedData
ln -s /Volumes/RamDisk/Caches/NeteaseMusic ~/Library/Containers/com.netease.163music/Data/Caches
```
> 其他软件缓存如需要放进RamDisk可如法炮制.

OK，重启电脑，Enjoy it！

	sudo halt



