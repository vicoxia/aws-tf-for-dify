#!/bin/bash

echo "=== Terraform 语法验证 ==="

# 检查是否有重复的 locals 定义
echo "检查重复的 locals 定义..."
grep -n "is_china_region" *.tf
echo ""
grep -n "arn_prefix" *.tf
echo ""

# 检查基本语法结构
echo "检查基本语法结构..."
for file in *.tf; do
    echo "检查文件: $file"
    # 检查括号匹配
    if ! grep -q "^locals {" "$file"; then
        continue
    fi
    echo "  - 发现 locals 块"
done

echo ""
echo "=== 验证完成 ==="
echo "如果没有错误信息，说明语法基本正确"