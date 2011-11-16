#!/bin/bash

#传入漫画所在目录
#./kindel_comic.sh -d ~/comic/doraemon -p left -o zip

#全局参数
POS="left" #漫画的阅读方向
DIR="" 
TARGET_TYPE="dir"

#检查传入参数
while getopts ":p:d:o:" optname
do
    case "$optname" in
        p) #漫画的阅读方向 left /right ，默认left
            POS="left"; test "$OPTARG" = "right" && POS="right"
            ;;
        d) #检查漫画所在的目录
            #dir方式
            test -d "$OPTARG" && DIR="$OPTARG" && continue;
            #zip方式
            file_type="`file $OPTARG`"
            if [ `expr match "$file_type" ".*Zip archive data.*"` -gt 0 ]; then 
                dir_path="${OPTARG%\.zip}"
                mkdir -p $dir_path
                unzip -x $OPTARG -d $dir_path > /dev/null
                DIR="$dir_path"
                
                continue;
            fi
            echo "Unknown dir $OPTARG" 
            ;;
        o) ##是否打包zip? or dir?
            test "zip" = "$OPTARG" && TARGET_TYPE="zip"
            ;;
        \?) echo "Unknown option $OPTARG" ;;
        ":") echo "No argument value for option $OPTARG" ;;
        *) # Should not occur
            echo "Unknown error while processing options"
    esac
done
test -z "$DIR" && echo "No argument value for option dir" && exit 1

#图片宽度
get_width(){
    echo "`identify $1 | cut -d ' ' -f 3 | cut -d 'x' -f 1`"
}

#图片高度
get_height(){
    echo "`identify $1 | cut -d ' ' -f 3 | cut -d 'x' -f 2`"
}


split_comic(){
    #进入漫画所在目录
    cd $DIR; pwd
    #遍历所在文件
    for i in `ls` ; do 
        #利用identify 过滤非图片文件
        identify $i > /dev/null; test "$?" != 0 && continue
        #如果是两页连在一起的图片从中点切图。根据长宽比例判断
        if [ "`get_width $i`" -gt "`get_height $i`" ] ; then
            convert $i -crop 2x1@ +repage +adjoin $i ; test "$POS" = "right" && mv "${i%.*}-0.${i##*.}" "${i%.*}-2.${i##*.}" #处理从右向左阅读的漫画
            rm $i -f #删除原始图片
        fi
    done
    cd -
    
    #输出漫画包的格式
    case "$TARGET_TYPE" in
        "zip") #压缩成一个zip文件，方便放到Kindle中
            zip_file_name="${DIR%\/}.kindle.zip"
            test "$zip_file_name" = ".kindle.zip" && zip_file_name="/compress.kindle.zip"
            _pwd="$PWD"
            cd $DIR
            test "${zip_file_name:0:1}" != "/" && zip_file_name="${_pwd}/${zip_file_name}"
            ls | zip  -0 "${zip_file_name}" -@;
            cd -
            rm -rf $DIR
            echo "$zip_file_name"
            ;;
        "dir") echo $DIR ;;
        *) echo $DIR ;;
    esac
    rm .split_comic_tag
}

process_bar(){
    while [ -e .split_comic_tag ]
    do
        for j  in  '-' '\\' '|' '/'
        do
            tput  sc #保存当前光标所在位置
            echo -ne  "Please waiting ... .... $j"
            sleep 0.1
            tput rc #恢复光标到最后保存的位置
        done
    done
}

main() {
    echo "DONOT PRESS Ctrl-C"
    touch .split_comic_tag    
    { 
        #split_comic 
        split_comic > /dev/null
    }&
    process_bar 
    wait
}

#call main
main
