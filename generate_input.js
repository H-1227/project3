const { readFileSync, writeFileSync } = require('fs');

// 生成Poseidon2哈希电路的输入
function generateInput(preimage, expectedHash) {
    return {
        "preimage": preimage,
        "expectedHash": expectedHash
    };
}

// 示例：使用随机值生成输入
function generateRandomInput() {
    // 对于(256,3,5)配置，RATE = 2
    const preimage = [
        BigInt(Math.floor(Math.random() * 1e18)),
        BigInt(Math.floor(Math.random() * 1e18))
    ];
    
    // 注意：实际使用时，这里的expectedHash应该是通过真实的Poseidon2实现计算得到的
    const expectedHash = BigInt(Math.floor(Math.random() * 1e18));
    
    return generateInput(preimage, expectedHash);
}

// 生成并保存输入文件
const input = generateRandomInput();
writeFileSync('input.json', JSON.stringify(input, (key, value) => 
    typeof value === 'bigint' ? value.toString() : value
));

console.log('输入文件已生成: input.json');
console.log('注意：实际使用时，expectedHash应通过真实的Poseidon2实现计算');
    