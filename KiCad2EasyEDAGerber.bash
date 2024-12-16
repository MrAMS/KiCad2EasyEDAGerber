#!/bin/bash

if [ -z "$1" ]; then
    echo "Usage: $0 <project_dir>"
    exit 1
fi

PCB_NAME=$(basename "$1")
echo "PCB Name=$PCB_NAME"
WORK_DIR="$1/production"

TMP_DIR="$WORK_DIR/tmp"
IN_ZIP="$WORK_DIR/$PCB_NAME.zip"
OUT_NAME="Gerber_${PCB_NAME}_$(date +"%Y-%m-%d")"
OUT_DIR="$WORK_DIR/$OUT_NAME"
OUT_ZIP="$WORK_DIR/$OUT_NAME.zip"

EasyEDA_VERSION="EasyEDA Pro v2.2.32.3"
DATE=$(date +"%Y-%m-%d %H:%M:%S")

if ! ls $IN_ZIP 1>/dev/null 2>&1; then
    echo "Production zip file not found, please make sure to run JLC-Plugin-for-KiCad at first or check your path"
    exit 1
fi

# 函数：替换文件头部信息并重命名文件
replace_header_and_rename() {
  local regex="$1"
  local rule="$2"
  
  # 查找符合正则表达式的文件
  for file in $(find $TMP_DIR -type f -regextype posix-extended -regex ".*/$regex"); do
    
    local new_name=$(basename "$file" | sed -E "$rule")   
    local layername=$(echo "$new_name" | sed -E 's/^(Drill|Gerber)_([^.]+)\..*$/\2/')
    echo "WORKING ON LAYER $layername"
    if grep -qE "^G04" "$file" ; then
      # echo "Gerber File"
      sed -i '/^G04/d' "$file"
      echo "G04 Layer: $layername*
G04 $EasyEDA_VERSION, $DATE*
G04 Gerber Generator version 0.3*
G04 Scale: 100 percent, Rotated: No, Reflected: No*
G04 Dimensions in millimeters*
G04 Leading zeros omitted, absolute positions, 3 integers and 5 decimals*" | cat - "$file" > temp && mv temp "$file"
    else
      # echo "DRL File"
      local plated_type="PLATED"
      if [[ $regex == *"NPTH"* ]]; then
        plated_type="NON_PLATED"
      fi
      echo ";TYPE=$plated_type
;Layer: $layername
;$EasyEDA_VERSION, $DATE
;Gerber Generator version 0.3" | cat - "$file" > temp && mv temp "$file"
    fi

    # 重命名文件
    mv "$file" "$OUT_DIR/$new_name"
  done
}

declare -A rename_rules=(
# 钻孔
  [".*\-NPTH\.drl"]="s/.*\-NPTH\.drl$/Drill_NPTH_Through.DRL/"
  [".*\-PTH\.drl"]="s/.*\-PTH\.drl$/Drill_PTH_Through.DRL/"
# 机械层
  [".*\.gm([0-9]+)$"]="s/.*\.gm([0-9]+)$/Gerber_MechanicalLayer\1.GM\1/"
# 顶层
  [".*\.gtl"]="s/.*\.gtl$/Gerber_TopLayer.GTL/"
  [".*\.gtp"]="s/.*\.gtp$/Gerber_TopPasteMaskLayer.GTP/"
  [".*\.gto"]="s/.*\.gto$/Gerber_TopSilkscreenLayer.GTO/"
  [".*\.gts"]="s/.*\.gts$/Gerber_TopSolderMaskLayer.GTS/"
# 中间层
  [".*\.gp([0-9]+)$"]="s/.*\.gp([0-9]+)$/Gerber_InnerLayer\1.GP\1/"
  [".*\.g([0-9]+)$"]="s/.*\.g([0-9]+)$/Gerber_InnerLayer\1.G\1/"
# 底层
  [".*\.gbl"]="s/.*\.gbl$/Gerber_BottomLayer.GBL/"
  [".*\.gbo"]="s/.*\.gbo$/Gerber_BottomSilkscreenLayer.GBO/"
  [".*\.gbs"]="s/.*\.gbs$/Gerber_BottomSolderMaskLayer.GBS/"
)

rm -r $TMP_DIR
rm -r $OUT_DIR
rm $OUT_ZIP
mkdir $TMP_DIR
mkdir $OUT_DIR
echo "WORKING IN $OUT_DIR ..."
unzip -o $IN_ZIP -d $TMP_DIR

# 应用所有重命名规则
for regex in "${!rename_rules[@]}"; do
  replace_header_and_rename "$regex" "${rename_rules[$regex]}"
done

echo "How to Order PCB

Please refer to:
https://prodocs.lceda.cn/cn/pcb/order-order-pcb/index.html" > $OUT_DIR/How-to-order-PCB.txt

zip -r -j $OUT_ZIP $OUT_DIR/*

rm -r $TMP_DIR
rm -r $OUT_DIR

echo "DONE. CHECK $OUT_ZIP."


