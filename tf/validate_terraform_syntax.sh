#!/bin/bash

echo "=== Terraform 语法验证 ==="

# 检查是否有多行条件表达式
echo "1. 检查多行条件表达式..."
if grep -n "?" *.tf | grep -v "# " | while read line; do
    file=$(echo "$line" | cut -d: -f1)
    linenum=$(echo "$line" | cut -d: -f2)
    
    # 检查下一行是否有缩进（表示多行表达式）
    next_line=$((linenum + 1))
    if sed -n "${next_line}p" "$file" | grep -q "^[[:space:]]\+"; then
        echo "❌ 发现多行条件表达式在 $file:$linenum"
        echo "   $(echo "$line" | cut -d: -f3-)"
        return 1
    fi
done; then
    echo "✅ 没有发现多行条件表达式"
else
    echo "❌ 发现多行条件表达式，需要修复"
fi

echo ""
echo "2. 检查关键文件语法..."

# 检查 rds.tf 中的 command 配置
if grep -A 3 "command.*local\.is_china_region" rds.tf | grep -q "bash.*create_dify_databases"; then
    echo "✅ rds.tf 中的脚本选择逻辑正确"
else
    echo "❌ rds.tf 中的脚本选择逻辑有问题"
fi

# 检查 locals.tf 中的变量定义
if grep -q "is_china_region.*contains" locals.tf; then
    echo "✅ locals.tf 中的区域检测逻辑正确"
else
    echo "❌ locals.tf 中的区域检测逻辑有问题"
fi

echo ""
echo "3. 建议的修复方法..."
echo "如果发现多行条件表达式，请将其合并为单行："
echo ""
echo "❌ 错误写法:"
echo "command = local.is_china_region ?"
echo "  \"script1\" :"
echo "  \"script2\""
echo ""
echo "✅ 正确写法:"
echo "command = local.is_china_region ? \"script1\" : \"script2\""
echo ""
echo "或者使用括号:"
echo "command = ("
echo "  local.is_china_region ?"
echo "  \"script1\" :"
echo "  \"script2\""
echo ")"