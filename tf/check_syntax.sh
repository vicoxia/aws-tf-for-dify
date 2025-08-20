#!/bin/bash

echo "=== 检查 Terraform 语法 ==="

# 检查 rds.tf 中的条件表达式语法
echo "检查 rds.tf 中的条件表达式..."

# 查找可能的语法问题
if grep -n "local\.is_china_region.*?" rds.tf; then
    echo "✅ 找到正确的条件表达式语法"
else
    echo "❌ 未找到条件表达式或语法可能有问题"
fi

# 检查是否还有复杂的条件表达式
if grep -n "var\.aws_region.*||" rds.tf; then
    echo "❌ 仍然存在复杂的条件表达式，需要修复"
else
    echo "✅ 没有发现复杂的条件表达式"
fi

# 检查 locals.tf 中的变量定义
echo ""
echo "检查 locals.tf 中的变量定义..."
if grep -n "is_china_region" locals.tf; then
    echo "✅ 找到 is_china_region 变量定义"
else
    echo "❌ 未找到 is_china_region 变量定义"
fi

echo ""
echo "=== 语法检查完成 ==="