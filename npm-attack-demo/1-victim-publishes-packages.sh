#!/bin/bash

# ========================================
# 受害者视角：正常发布npm包
# ========================================

echo "========================================="
echo "[受害者] 正在发布第一个包 victim-package-a"
echo "========================================="

cd victim-packages/package-a

# 模拟登录npm
echo "[受害者] npm login"
echo "Username: victim-user"
echo "Password: ********"
echo "Email: victim@example.com"
echo ""

# 模拟发布
echo "[受害者] npm publish"
echo "✓ Package victim-package-a@1.0.0 published successfully"
echo ""

cd ../package-b

echo "========================================="
echo "[受害者] 正在发布第二个包 victim-package-b"
echo "========================================="

# 模拟发布
echo "[受害者] npm publish"
echo "✓ Package victim-package-b@1.0.0 published successfully"
echo ""

echo "✓ 两个包都已成功发布到npm registry"
echo "✓ 当前用户: victim-user"
echo ""

# 显示npm token的存储位置
echo "[关键信息] npm token 存储位置："
echo "  - ~/.npmrc 文件中包含认证token"
echo "  - 格式: //registry.npmjs.org/:_authToken=${NPM_TOKEN}"
echo "  - 攻击者只要获得这个token就能控制用户的所有包"
echo ""
