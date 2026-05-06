#!/bin/bash

# BZGram 自动打包脚本 (跳过签名生成 IPA)

echo "🚀 开始更新版本号..."
# 获取当前 Build 号并加 1
CURRENT_BUILD=$(grep "CURRENT_PROJECT_VERSION:" project.yml | head -1 | awk '{print $2}' | tr -d '"')
NEW_BUILD=$((CURRENT_BUILD + 1))
sed -i '' "s/CURRENT_PROJECT_VERSION: $CURRENT_BUILD/CURRENT_PROJECT_VERSION: $NEW_BUILD/g" project.yml

# 获取当前 Marketing Version 并增加末尾的小版本号
CURRENT_MARKETING=$(grep "MARKETING_VERSION:" project.yml | head -1 | awk '{print $2}' | tr -d '"')
# 假设格式是 x.y.z，我们将 z 加 1
BASE_VERSION=$(echo $CURRENT_MARKETING | cut -d. -f1,2)
PATCH_VERSION=$(echo $CURRENT_MARKETING | cut -d. -f3)
NEW_PATCH=$((PATCH_VERSION + 1))
NEW_MARKETING="${BASE_VERSION}.${NEW_PATCH}"
sed -i '' "s/MARKETING_VERSION: $CURRENT_MARKETING/MARKETING_VERSION: $NEW_MARKETING/g" project.yml

echo "📈 版本号已更新：Build -> $NEW_BUILD, Version -> $NEW_MARKETING"

echo "🔄 正在彻底清理旧缓存 (DerivedData)..."
rm -rf ./DerivedData

echo "🔄 正在同步工程配置 (xcodegen)..."
xcodegen generate

echo "🚀 开始编译 BZGram (Release)..."

# 1. 强制跳过签名限制进行 Release 编译
xcodebuild clean build \
  -scheme BZGram \
  -project BZGram.xcodeproj \
  -configuration Release \
  -destination 'generic/platform=iOS' \
  CODE_SIGNING_ALLOWED=NO \
  CODE_SIGNING_REQUIRED=NO \
  CODE_SIGN_IDENTITY="" \
  CODE_SIGN_ENTITLEMENTS="" \
  -derivedDataPath ./DerivedData

if [ $? -eq 0 ]; then
    echo "✅ 编译成功，正在打包 TIPA..."
    
    # 2. 将编译产物打包为 TIPA
    rm -rf Payload
    mkdir -p Payload
    cp -R ./DerivedData/Build/Products/Release-iphoneos/BZGram.app Payload/
    
    # 生成最终文件名 (包含 Version 和 Build)
    FILENAME="Builds/BZGram_v${NEW_MARKETING}_Build${NEW_BUILD}_$(date +%m%d).tipa"
    zip -r "$FILENAME" Payload
    
    rm -rf Payload
    echo "🎉 打包完成！文件已生成: $FILENAME"
    echo "📂 请在 Builds/ 文件夹中查看。"
else
    echo "❌ 编译失败，请检查上面的错误日志。"
    exit 1
fi
