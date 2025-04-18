message(0xaaaaaaa1) AddLiquidity {
    queryId: Int;
    newAmount0: Int;
    newAmount1: Int;
    minLPOut: Int;
}

message(0xaaaaaaa2) CbAddLiquidity {
    queryId: Int;
    amount0: Int;
    amount1: Int;
    userAddress: Address;
    minLPOut: Int;
}

message(0xaaaaaaa3) RefundMe {
    queryId: Int;
}

message(0xaaaaaaa4) CbRefundMe {
    queryId: Int;
    amount0: Int;
    amount1: Int;
    userAddress: Address;
}

message(0xaaaaaaa5) DirectAddLiquidity {
    queryId: Int;
    amount0: Int;
    amount1: Int;
    minLPOut: Int;
}

message(0xaaaaaaa6) Swap {
    queryId: Int as uint64;
    fromAddress: Address;
    tokenWallet: Address;
    jettonAmount: Int as coins;
    minOutput: Int as coins;
    hasRef: Bool;
    fromRealUser: Address;
    refAddress: Address?;
}

message(0xaaaaaaa7) ProvideLP {
    queryId: Int as uint64;
    fromUser: Address;
    minLPOut: Int as coins;
    amount0: Int as coins;
    amount1: Int as coins; 
}

message(0xaaaaaaa8) PayTo {
    queryId: Int as uint64;
    toAddress: Address;
    exitCode: Int as uint32;
    amount0Out: Int as coins;
    token0Address: Address;
    amount1Out: Int as coins;
    token1Address: Address;
}

message(0xaaaaaaa9) PoolSetFees {
    queryId: Int as uint64;
    newLPFee: Int as uint8;
    newProtocolFee: Int as uint8;
    newRefFee: Int as uint8;
    newProtocolFeeAddress: Address;
}

message(0xaaaaaa10) ResetGas {
    queryId: Int as uint64;
}

message(0xaaaaaa11) ResetPoolGas {
    queryId: Int as uint64;
    token0Address: Address;
    token1Address: Address;
}

message(0xaaaaaa12) Lock {
    queryId: Int as uint64;
}

message(0xaaaaaa13) Unlock {
    queryId: Int as uint64;
}

message(0xaaaaaa14) RouterSetFees {
    queryId: Int as uint64;
    newLPFee: Int as uint8;
    newProtocolFee: Int as uint8;
    newRefFee: Int as uint8;
    newProtocolFeeAddress: Address;
    token0Address: Address;
    token1Address: Address;
}

message(0xaaaaaa15) RouterCollectFees {
    queryId: Int as uint64;
    token0Address: Address;
    token1Address: Address;
}

message(0xaaaaaa16) PoolCollectFees {
    queryId: Int as uint64;
}

message(0xaaaaaa16) UserCollectFees {
    queryId: Int as uint64;
}

struct AmountOut {
    out: Int as coins; 
    protocolFeeOut: Int as coins;
    refFeeOut: Int as coins;
}

struct PoolData {
    routerAddress: Address;
    LPFee: Int as uint8;
    protocolFee: Int as uint8;
    refFee: Int as uint8;
    token0Address: Address;
    token1Address: Address;
    totalSupplyLP: Int as coins; 
    collectedToken0ProtocolFee: Int as coins;
    collectedToken1ProtocolFee: Int as coins; 
    protocolFeeAddress: Address;
    reserve0: Int as coins;
    reserve1: Int as coins; 
}

struct LPAccountData {
    userAddress: Address;
    poolAddress: Address;
    amount0: Int as coins;
    amount1: Int as coins;
}

struct Amounts {
    amount0: Int as coins;
    amount1: Int as coins;
}

// ============================================================
// Jetton messages

message(0xf8a7ea5) JettonTransfer {
    queryId: Int as uint64;
    amount: Int as coins;
    destination: Address;
    responseDestination: Address?;
    customPayload: Cell?;
    forwardTonAmount: Int as coins;
    forwardPayload: Slice as remaining;
}

message(0x178d4519) JettonTransferInternal {
    queryId: Int as uint64;
    amount: Int as coins;
    sender: Address;
    responseDestination: Address?;
    forwardTonAmount: Int as coins;
    forwardPayload: Slice as remaining;
}

message(0x7362d09c) JettonNotification {
    queryId: Int as uint64;
    amount: Int as coins;
    sender: Address;
    forwardPayload: Slice as remaining;
}

message(0x595f07bc) JettonBurn {
    queryId: Int as uint64;
    amount: Int as coins;
    responseDestination: Address?;
    customPayload: Cell?;
}

message(0x7bdd97de) JettonBurnNotification {
    queryId: Int as uint64;
    amount: Int as coins;
    sender: Address;
    responseDestination: Address?;
}

message(0xd53276db) JettonExcesses {
    queryId: Int as uint64;
}

struct JettonWalletData {
    balance: Int;
    owner: Address;
    minter: Address;
    code: Cell;
}

message(0x2c76b973) ProvideWalletAddress {
    queryId: Int as uint64;
    ownerAddress: Address;
    includeAddress: Bool;
}

// ============================================================

const WORKCHAIN: Int = 0;
const MAX_COINS: Int = 1329227995784915872903807060280344575;
const REQUIRED_MIN_LIQUIDITY: Int = 1000;
const FEE_DIVIDER: Int = 10000;
const HOLE_ADDRESS: Address = address("EQAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAM9c");
const MIN_FEE: Int = 0;
const MAX_FEE: Int = 100;
const REQUIRED_TON_RESERVE: Int = 10000000;


const SWAP: Int = 0xfffffff1;
const PROVIDE_LP: Int = 0xfffffff2;
const SWAP_REFUND_RESERVE_ERR: Int = 0xfffffff3;
const SWAP_OK: Int = 0xfffffff4;
const REFUND_OK: Int = 0xfffffff5;
const SWAP_OK_REF: Int = 0xfffffff6;
const BURN_OK: Int = 0xfffffff7;


const TakeWalletAddressOpcode: Int = 0xd1735400;
const gasForBurn: Int = 6700;
const gasForTransfer: Int = 10500;
const minTonsForStorage: Int = ton("0.01"); // This should use https://github.com/tact-lang/tact/issues/2336 in the future
const Basechain: Int = 0;


const WRONG_OP: Int = 1001;
const ZERO_OUTPUT: Int = 1002;
const NO_LIQUIDITY: Int = 1003; 
const INSUFFICIENT_GAS: Int = 1004;
const INVALID_CALLER: Int = 1005;
const INVALID_AMOUNT: Int = 1006;
const WRONG_CALLER: Int = 1007;
const SWAP_REFUND_NO_LIQ: Int = 1008;
const LOW_LIQUIDITY: Int = 1009;
const REQUIRED_MIN_COLLECT_FEES: Int = 1010;
const FEE_OUT_OF_RANGE: Int = 1011;
const INVALID_RECIPIENT: Int = 1012;
const INVALID_TOKEN: Int = 1013;