#!/bin/bash

echo "=== 检查特定的语法问题 ==="

# 检查 outputs.tf 中的条件表达式
echo "检查 outputs.tf 中的条件表达式..."
if grep -n "next_steps.*?" outputs.tf; then
    echo "✅ 找到 next_steps 条件表达式"
    
    # 检查是否为单行
    line_num=$(grep -n "next_steps.*?" outputs.tf | cut -d: -f1)
    line_content=$(sed -n "${line_num}p" outputs.tf)
    
    if echo "$line_content" | grep -q "数据库已自动创建完成"; then
        echo "✅ next_steps 条件表达式为单行，语法正确"
    else
        echo "❌ next_steps 条件表达式可能为多行，需要检查"
    fi
else
    echo "❌ 未找到 next_steps 条件表达式"
fi

echo ""
echo "检查 rds.tf 中的 command 配置..."
if grep -n "command.*local\.is_china_region" rds.tf; then
    echo "✅ 找到 command 条件表达式"
    
    # 检查是否为单行
    line_num=$(grep -n "command.*local\.is_china_region" rds.tf | cut -d: -f1)
    line_content=$(sed -n "${line_num}p" rds.tf)
    
    if echo "$line_content" | grep -q "create_dify_databases_dataapi.sh"; then
        echo "✅ command 条件表达式为单行，语法正确"
    else
        echo "❌ command 条件表达式可能为多行，需要检查"
    fi
else
    echo "❌ 未找到 command 条件表达式"
fi

echo ""
echo "=== 检查完成 ==="