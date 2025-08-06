include "node_modules/circomlib/circuits/gates.circom";
include "node_modules/circomlib/circuits/bitify.circom";

// 常量定义 - 参考文档1中Table1的(256,3,5)参数
const N = 256;       // 输出长度
const T = 3;         // 状态大小 (rate + capacity)
const RATE = T - 1;  // 输入率
const D = 5;         // S-box指数
const ROUNDS_F = 8;  // 完全轮数
const ROUNDS_P = 4;  // 部分轮数
const TOTAL_ROUNDS = ROUNDS_F + ROUNDS_P;

// 轮常量 - 简化版，实际应使用文档中指定的常量
// 这里使用示例值，实际应用中需替换为官方定义的常量
function roundConstants(i) {
    return [
        // 第0轮常量
        [0x0000000000000001n, 0x0000000000000002n, 0x0000000000000003n],
        // 第1轮常量
        [0x0000000000000004n, 0x0000000000000005n, 0x0000000000000006n],
        // 第2轮常量
        [0x0000000000000007n, 0x0000000000000008n, 0x0000000000000009n],
        // 第3轮常量
        [0x000000000000000an, 0x000000000000000bn, 0x000000000000000cn],
        // 第4轮常量
        [0x000000000000000dn, 0x000000000000000en, 0x000000000000000fn],
        // 第5轮常量
        [0x0000000000000010n, 0x0000000000000011n, 0x0000000000000012n],
        // 第6轮常量
        [0x0000000000000013n, 0x0000000000000014n, 0x0000000000000015n],
        // 第7轮常量
        [0x0000000000000016n, 0x0000000000000017n, 0x0000000000000018n],
        // 第8轮常量
        [0x0000000000000019n, 0x000000000000001an, 0x000000000000001bn],
        // 第9轮常量
        [0x000000000000001cn, 0x000000000000001dn, 0x000000000000001en],
        // 第10轮常量
        [0x000000000000001fn, 0x0000000000000020n, 0x0000000000000021n],
        // 第11轮常量
        [0x0000000000000022n, 0x0000000000000023n, 0x0000000000000024n]
    ][i];
}

// 部分轮的活跃元素索引
function partialRoundActiveIndex(round) {
    // 部分轮中激活的S-box索引
    return [1, 2, 1, 2][round];
}

// 模运算辅助函数
template ModConstant(n) {
    signal input in;
    signal output out;
    out <== in % n;
}

// 有限域上的加法
template AddMod(p) {
    signal input a;
    signal input b;
    signal output out;
    
    component mod = ModConstant(p);
    mod.in <== a + b;
    out <== mod.out;
}

// 有限域上的乘法
template MulMod(p) {
    signal input a;
    signal input b;
    signal output out;
    
    component mod = ModConstant(p);
    mod.in <== a * b;
    out <== mod.out;
}

// 幂运算模板 - 用于S-box变换 (x^D mod p)
template PowMod(p, e) {
    signal input in;
    signal output out;
    
    if (e == 0) {
        out <== 1;
    } else {
        signal temp;
        temp <== in;
        
        for (var i = 1; i < e; i++) {
            component mul = MulMod(p);
            mul.a <== temp;
            mul.b <== in;
            temp <== mul.out;
        }
        
        out <== temp;
    }
}

// S-box变换 - 对于Poseidon2使用x^5
template SBox(p) {
    signal input in;
    signal output out;
    
    component pow = PowMod(p, D);
    pow.in <== in;
    out <== pow.out;
}

// 线性变换 - 简化版MixLayer
template MixLayer(p) {
    signal input in[T];
    signal output out[T];
    
    // 简化的混合矩阵，实际应使用文档中定义的矩阵
    // 这里使用单位矩阵的变体作为示例
    for (var i = 0; i < T; i++) {
        signal sum;
        sum <== 0;
        
        for (var j = 0; j < T; j++) {
            component mul = MulMod(p);
            mul.a <== in[j];
            mul.b <== (i == j) ? 1 : 1;  // 简化矩阵
            sum += mul.out;
        }
        
        component mod = ModConstant(p);
        mod.in <== sum;
        out[i] <== mod.out;
    }
}

// 完整轮变换
template FullRound(p, round) {
    signal input state[T];
    signal output out[T];
    
    // 1. 添加轮常量
    signal afterAdd[T];
    for (var i = 0; i < T; i++) {
        component add = AddMod(p);
        add.a <== state[i];
        add.b <== roundConstants(round)[i];
        afterAdd[i] <== add.out;
    }
    
    // 2. 应用S-box到所有元素
    signal afterSBox[T];
    for (var i = 0; i < T; i++) {
        component sbox = SBox(p);
        sbox.in <== afterAdd[i];
        afterSBox[i] <== sbox.out;
    }
    
    // 3. 应用线性变换
    component mix = MixLayer(p);
    for (var i = 0; i < T; i++) {
        mix.in[i] <== afterSBox[i];
    }
    
    // 输出结果
    for (var i = 0; i < T; i++) {
        out[i] <== mix.out[i];
    }
}

// 部分轮变换
template PartialRound(p, round, activeIdx) {
    signal input state[T];
    signal output out[T];
    
    // 1. 添加轮常量
    signal afterAdd[T];
    for (var i = 0; i < T; i++) {
        component add = AddMod(p);
        add.a <== state[i];
        add.b <== roundConstants(round)[i];
        afterAdd[i] <== add.out;
    }
    
    // 2. 仅对活跃元素应用S-box
    signal afterSBox[T];
    for (var i = 0; i < T; i++) {
        if (i == activeIdx) {
            component sbox = SBox(p);
            sbox.in <== afterAdd[i];
            afterSBox[i] <== sbox.out;
        } else {
            afterSBox[i] <== afterAdd[i];
        }
    }
    
    // 3. 应用线性变换
    component mix = MixLayer(p);
    for (var i = 0; i < T; i++) {
        mix.in[i] <== afterSBox[i];
    }
    
    // 输出结果
    for (var i = 0; i < T; i++) {
        out[i] <== mix.out[i];
    }
}

// Poseidon2哈希模板
template Poseidon2Hash(p) {
    // 输入：隐私输入（哈希原象）
    signal private input inputs[RATE];
    
    // 输出：公开输出（哈希结果）
    signal output hash;
    
    // 初始化状态：容量部分初始化为0，输入部分来自输入
    signal state[T];
    for (var i = 0; i < RATE; i++) {
        state[i] <== inputs[i];
    }
    state[RATE] <== 0;  // 容量元素初始化为0
    
    // 前半部分完全轮
    for (var r = 0; r < ROUNDS_F / 2; r++) {
        component round = FullRound(p, r);
        for (var i = 0; i < T; i++) {
            round.state[i] <== state[i];
        }
        for (var i = 0; i < T; i++) {
            state[i] <== round.out[i];
        }
    }
    
    // 部分轮
    for (var r = 0; r < ROUNDS_P; r++) {
        var roundIdx = ROUNDS_F / 2 + r;
        var activeIdx = partialRoundActiveIndex(r);
        
        component round = PartialRound(p, roundIdx, activeIdx);
        for (var i = 0; i < T; i++) {
            round.state[i] <== state[i];
        }
        for (var i = 0; i < T; i++) {
            state[i] <== round.out[i];
        }
    }
    
    // 后半部分完全轮
    for (var r = 0; r < ROUNDS_F / 2; r++) {
        var roundIdx = ROUNDS_F / 2 + ROUNDS_P + r;
        
        component round = FullRound(p, roundIdx);
        for (var i = 0; i < T; i++) {
            round.state[i] <== state[i];
        }
        for (var i = 0; i < T; i++) {
            state[i] <== round.out[i];
        }
    }
    
    // 输出哈希结果（取状态的第一个元素）
    hash <== state[0];
}

// 主电路：验证哈希原象与哈希值的关系
template Poseidon2Circuit() {
    // 选择素数p = 2^256 - 2^32 - 2^9 - 2^8 - 2^7 - 2^6 - 2^4 - 1
    // 这是一个常用于zk-SNARK的256位素数
    const p = 0x10000000000000000000000000000000000000000000000000000000000000000n 
             - 0x100000000n 
             - 0x200n 
             - 0x80n 
             - 0x40n 
             - 0x20n 
             - 0x10n 
             - 1n;
    
    // 隐私输入：哈希原象（RATE个元素）
    signal private input preimage[RATE];
    
    // 公开输入：预期的哈希值
    signal public input expectedHash;
    
    // 计算哈希值
    component hasher = Poseidon2Hash(p);
    for (var i = 0; i < RATE; i++) {
        hasher.inputs[i] <== preimage[i];
    }
    
    // 约束：计算出的哈希值必须等于预期的哈希值
    hasher.hash === expectedHash;
}

// 实例化电路
component main = Poseidon2Circuit();
    