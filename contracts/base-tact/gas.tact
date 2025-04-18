// gas_prices#dd gas_price:uint64 gas_limit:uint64 gas_credit:uint64 
//   block_gas_limit:uint64 freeze_due_limit:uint64 delete_due_limit:uint64 
//   = GasLimitsPrices;

// gas_prices_ext#de gas_price:uint64 gas_limit:uint64 special_gas_limit:uint64 gas_credit:uint64 
//   block_gas_limit:uint64 freeze_due_limit:uint64 delete_due_limit:uint64 
//   = GasLimitsPrices;

// gas_flat_pfx#d1 flat_gas_limit:uint64 flat_gas_price:uint64 other:GasLimitsPrices
//   = GasLimitsPrices;


inline fun getGasFee(gasAmount: Int, workchain: Int): Int {
    let gasLimitsPrices: Slice = (workchain == -1 ? getConfigParam(20)!! : getConfigParam(21)!!).beginParse();
    let tag: Int = gasLimitsPrices.loadUint(8);
    let flatGasLimit: Int = 0;
    let flatGasPrice: Int = 0;
    let gasPrice: Int = 0;
    if (tag == 0xd1) {
        flatGasLimit = gasLimitsPrices.loadUint(64);
        flatGasPrice = gasLimitsPrices.loadUint(64);

        tag = gasLimitsPrices.loadUint(8);
    } 
    if ((tag == 0xde) || (tag == 0xdd)) {
        gasPrice = gasLimitsPrices.loadUint(64);
    } 

    return gasAmount < flatGasLimit ?
               flatGasPrice :
               (gasAmount - flatGasLimit) * (gasPrice >> 16) + flatGasPrice;
}

// asm fun emptyAddress(): Address { b{00} PUSHSLICE }