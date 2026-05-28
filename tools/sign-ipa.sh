#!/usr/bin/env bash
# 给 Tonari 打一个用 Shuang Liu 证书签的正式 ipa。
# 源码 Bundle ID 永远是 com.leo.tonari(给免费证书真机调试用)。
# 这个脚本会在 Runner.app 内临时改成 mobileprovision 锁定的 Bundle ID 再签。
#
# 用法:
#   tools/sign-ipa.sh
#
# 前置:
#   - p12 与 mobileprovision 放在 certs/ (gitignored),或通过环境变量覆盖路径
#   - 已 import p12 到 login keychain (会自动尝试)
#
# 续费换证书时只需要替换 certs/ 下两份文件,Bundle ID 不一样的话同步改一下下面的 TARGET_BID。

set -euo pipefail

cd "$(dirname "$0")/.."

CERT_DIR="${CERT_DIR:-证书_C451E}"
P12_FILE="${P12_FILE:-$CERT_DIR/shuang liu.p12}"
P12_PASS="${P12_PASS:-123456}"
PROVISION_FILE="${PROVISION_FILE:-$CERT_DIR/00008..1C.mobileprovision}"

# 这两个值必须跟 mobileprovision 一致 — 切证书时记得同步改
TARGET_BID="com.wangshaikang"
TEAM_ID="BZTAR8DUF3"

APP_PATH="build/ios/iphoneos/Runner.app"
ENTITLEMENTS="build/signing/Runner.entitlements"
IPA_OUT="build/ios/iphoneos/tonari-signed.ipa"

echo "==> [1/6] flutter build (unsigned)"
flutter build ios --release --no-codesign

echo "==> [2/6] 改 Info.plist Bundle ID (临时,只在 Runner.app 内)"
/usr/libexec/PlistBuddy -c "Set :CFBundleIdentifier $TARGET_BID" "$APP_PATH/Info.plist"

echo "==> [3/6] 写最小 entitlements"
mkdir -p build/signing
cat > "$ENTITLEMENTS" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>application-identifier</key>
    <string>${TEAM_ID}.${TARGET_BID}</string>
    <key>com.apple.developer.team-identifier</key>
    <string>${TEAM_ID}</string>
    <key>keychain-access-groups</key>
    <array>
        <string>${TEAM_ID}.${TARGET_BID}</string>
    </array>
    <key>get-task-allow</key>
    <false/>
</dict>
</plist>
EOF

echo "==> [4/6] 导入 p12 + 找 identity"
security import "$P12_FILE" -k ~/Library/Keychains/login.keychain-db -P "$P12_PASS" -T /usr/bin/codesign 2>/dev/null || true
IDENTITY=$(security find-identity -v -p codesigning | grep "($TEAM_ID)" | head -1 | awk '{print $2}')
if [ -z "$IDENTITY" ]; then
  echo "❌ 找不到 team $TEAM_ID 的签名 identity,p12 没导入成功?"
  exit 1
fi
echo "    identity = $IDENTITY"

echo "==> [5/6] 嵌入 profile + 签 framework + 签主体"
cp "$PROVISION_FILE" "$APP_PATH/embedded.mobileprovision"
for fw in "$APP_PATH"/Frameworks/*.framework; do
  codesign --force --sign "$IDENTITY" "$fw"
done
codesign --force --sign "$IDENTITY" --entitlements "$ENTITLEMENTS" "$APP_PATH"
codesign --verify --verbose=2 "$APP_PATH"

echo "==> [6/6] 打包 ipa"
cd build/ios/iphoneos
rm -rf Payload tonari-signed.ipa
mkdir Payload
cp -R Runner.app Payload/
zip -qr tonari-signed.ipa Payload
rm -rf Payload

echo ""
echo "✅ done -> $(pwd)/tonari-signed.ipa ($(du -h tonari-signed.ipa | cut -f1))"
echo ""
echo "装机:用轻松签的「无需签名安装」/ 爱思助手「安装 ipa」/ 3uTools,**不要再被重签一次**"
