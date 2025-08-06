#!/bin/bash

# 确保安装了必要的工具
if ! command -v circom &> /dev/null
then
    echo "circom 未安装，请先安装: npm install -g circom"
    exit 1
fi

if ! command -v snarkjs &> /dev/null
then
    echo "snarkjs 未安装，请先安装: npm install -g snarkjs"
    exit 1
fi

# 创建输出目录
mkdir -p build

# 1. 编译电路
echo "编译电路..."
circom poseidon2.circom --r1cs --wasm --sym -o build/

# 2. 生成信任设置 (powers of tau)
echo "生成信任设置..."
snarkjs powersoftau new bn128 12 build/pot12_0000.ptau -v
snarkjs powersoftau contribute build/pot12_0000.ptau build/pot12_0001.ptau --name="First contribution" -v

# 3. 准备 phase 2
echo "准备phase 2..."
snarkjs powersoftau prepare phase2 build/pot12_0001.ptau build/pot12_final.ptau -v

# 4. 生成证明密钥和验证密钥
echo "生成证明和验证密钥..."
snarkjs groth16 setup build/poseidon2.r1cs build/pot12_final.ptau build/poseidon2_0000.zkey
snarkjs zkey contribute build/poseidon2_0000.zkey build/poseidon2_0001.zkey --name="1st Contributor Name" -v
snarkjs zkey export verificationkey build/poseidon2_0001.zkey build/verification_key.json

# 5. 生成 witness
echo "生成witness..."
node build/poseidon2_js/generate_witness.js build/poseidon2_js/poseidon2.wasm input.json build/witness.wtns

# 6. 生成证明
echo "生成证明..."
snarkjs groth16 prove build/poseidon2_0001.zkey build/witness.wtns build/proof.json build/public.json

# 7. 验证证明
echo "验证证明..."
snarkjs groth16 verify build/verification_key.json build/public.json build/proof.json

echo "所有步骤完成！"
    