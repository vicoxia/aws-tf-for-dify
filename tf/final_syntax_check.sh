#!/bin/bash

echo "=== 最终语法检查 ==="

# 检查关键的条件表达式是否为单行
echo "1. 检查 outputs.tf 中的关键条件表达式..."

# 检查 next_steps
if grep -A 1 "next_steps.*?" outputs.tf | grep -q "数据库已自动创建完成"; then
    echo "✅ next_steps 条件表达式为单行"
else
    echo "❌ next_steps 条件表达式可能有问题"
fi

# 检查其他关键条件表达式
echo ""
echo "2. 检查 rds.tf 中的配置..."

# 检查 count 配置
if grep -q "count = local.is_china_region ? 0 : 1" rds.tf; then
    echo "✅ 全球区域数据库创建的 count 配置正确"
else
    echo "❌ 全球区域数据库创建的 count 配置有问题"
fi

if grep -q "count = local.is_china_region ? 1 : 0" rds.tf; then
    echo "✅ 中国区域指导的 count 配置正确"
else
    echo "❌ 中国区域指导的 count 配置有问题"
fi

echo ""
echo "3. 检查 locals.tf 中的区域检测..."
if grep -q 'is_china_region = contains(\["cn-north-1", "cn-northwest-1"\], var.aws_region)' locals.tf; then
    echo "✅ 区域检测逻辑正确"
else
    echo "❌ 区域检测逻辑有问题"
fi

echo ""
echo "=== 检查结果 ==="
echo "如果所有项目都显示 ✅，则语法应该没有问题。"
echo "如果仍然有 terraform validate 错误，请检查具体的错误信息。"