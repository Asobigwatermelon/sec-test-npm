#!/bin/bash

# ========================================
# 攻击者视角：窃取npm token
# ========================================

echo "========================================="
echo "[攻击者] 正在窃取受害者的 npm token"
echo "========================================="
echo ""

# 攻击者通过各种方式窃取token：
echo "[攻击者] 窃取方式："
echo "  1. 通过恶意软件读取 ~/.npmrc 文件"
echo "  2. 通过CI/CD管道泄露的环境变量"
echo "  3. 通过钓鱼攻击获取"
echo "  4. 通过供应链攻击（恶意依赖包）"
echo ""

# 模拟token窃取
export NPM_TOKEN="npmabcdefghijklmnopqrstuvwxzy1234567890"
echo "[攻击者] ✓ 成功获取 token: ${NPM_TOKEN:0:20}..."
echo ""

# 保存token供后续使用
echo "NPM_TOKEN=${NPM_TOKEN}" > attacker-tools/.env
echo ""

echo "========================================="
echo "[攻击者] Token 窃取成功！"
echo "========================================="
echo ""
echo "[攻击者] 现在可以使用这个token："
echo "  - 查看用户的所有包"
echo "  - 修改任何包的内容"
echo "  - 发布新版本"
echo "  - 删除包"
echo ""
