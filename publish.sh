#!/bin/bash

# 本地手动发布脚本
# 用于发布 npm-attack-demo/victim-packages 中的两个包

set -e  # 遇到错误立即退出

# 颜色输出
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

echo -e "${YELLOW}========================================${NC}"
echo -e "${YELLOW}  NPM 包本地发布脚本${NC}"
echo -e "${YELLOW}========================================${NC}"

# 定义包目录
PACKAGES=(
  "npm-attack-demo/victim-packages/package-a"
  "npm-attack-demo/victim-packages/package-b"
)

# 检查 npm 认证
echo -e "\n${YELLOW}检查 npm 认证状态...${NC}"
if ! npm whoami >/dev/null 2>&1; then
    echo -e "${RED}错误: 未登录 npm${NC}"
    echo -e "${YELLOW}请运行: npm login${NC}"
    exit 1
fi
echo -e "${GREEN}✓ 已登录为: $(npm whoami)${NC}"

# 遍历发布每个包
for PACKAGE_DIR in "${PACKAGES[@]}"; do
    echo -e "\n${YELLOW}========================================${NC}"
    echo -e "${YELLOW}正在处理: $PACKAGE_DIR${NC}"
    echo -e "${YELLOW}========================================${NC}"

    cd "$PACKAGE_DIR"

    # 读取包名
    PACKAGE_NAME=$(node -p "require('./package.json').name")
    PACKAGE_VERSION=$(node -p "require('./package.json').version")

    echo -e "${GREEN}包名: $PACKAGE_NAME${NC}"
    echo -e "${GREEN}版本: $PACKAGE_VERSION${NC}"

    # 检查是否已发布
    if npm view "$PACKAGE_NAME" >/dev/null 2>&1; then
        PUBLISHED_VERSION=$(npm view "$PACKAGE_NAME" version)
        echo -e "${YELLOW}已发布版本: $PUBLISHED_VERSION${NC}"

        if [ "$PUBLISHED_VERSION" = "$PACKAGE_VERSION" ]; then
            echo -e "${YELLOW}当前版本已存在，跳过发布${NC}"
            cd - > /dev/null
            continue
        fi
    fi

    # 执行发布
    echo -e "${YELLOW}正在发布 $PACKAGE_NAME...${NC}"
    if npm publish --access public; then
        echo -e "${GREEN}✓ $PACKAGE_NAME 发布成功！${NC}"
    else
        echo -e "${RED}✗ $PACKAGE_NAME 发布失败${NC}"
        cd - > /dev/null
        continue
    fi

    cd - > /dev/null
done

echo -e "\n${GREEN}========================================${NC}"
echo -e "${GREEN}  发布完成！${NC}"
echo -e "${GREEN}========================================${NC}"
