struct Tick {
    liquidityGross: Int as uint128;
    liquidityNet: Int as uint128;
}


contract V3Pool {
    routerAddress: Address;
    token0Address: Address;
    token1Address: Address;
    reserve0: Int as coins;
    reserve1: Int as coins;
    tick: Int as int24;
    sqrtPrice: Int as uint160;

    ticks: map<Int as int24, Tick>;

    receive(msg: V3Swap) {

    }

    receive(msg: V3ProvideLP) {
        throwUnless(WRONG_CALLER, sender() == self.routerAddress);
        let LPAccountInit: StateInit = getLPAccountStateInit(msg.fromUser, myAddress());
        deploy(DeployParameters{
            init: LPAccountInit,
            value: 0,
            mode: SendRemainingValue,
            bounce: false,
            body: AddLiquidity{
                queryId: msg.queryId,
                newAmount0: msg.amount0,
                newAmount1: msg.amount1,
            }.toCell()
        }); 
    }

    receive(msg: CbAddLiquidity) {
        let LPAccountStateInit: StateInit = getLPAccountStateInit(msg.userAddress, myAddress());
        let LPAccountAddress: Address = contractAddress(LPAccountStateInit);
        throwUnless(INVALID_CALLER, sender() == LPAccountAddress);

        let sqrtPriceLower = tickToSqrtPrice(msg.lowerTick);
        let sqrtPriceUpper = tickToSqrtPrice(msg.upperTick);
        let liquidity = 0;
        if (self.tick < msg.lowerTick) {
            liquidity = (msg.amount0 * sqrtPriceUpper * sqrtPriceLower) / (sqrtPriceUpper - sqrtPriceLower);
        } else if (self.tick >= upperTick) {
            liquidity = msg.amount1 / (sqrtPriceUpper - sqrtPriceLower);
        } else {
            let L0 = (msg.amount0 * sqrtPriceUpper * currentSqrtPrice) / (sqrtPriceUpper - currentSqrtPrice);
            let L1 = msg.amount1 / (currentSqrtPrice - sqrtPriceLower);
            liquidity = min(L0, L1);
        }

        let lowerTick = self.ticks.get(,sg.lowerTick);
        lowerTick.liquidityNet += liquidity;
        lowerTick.liquidityGross += liquidity;
        self.ticks.replace(msg.lowerTick);

        let upperTick = self.ticks.get(msg.upperTick);
        upperTick.liquidityNet -= liquidity;
        upperTick.liquidityGross += liquidity;
        self.ticks.replace(msg.upperTick);

        // mint position(userAddress, lowerTick, upperTick, liquidity)

        self.reserve0 += msg.amount0;
        self.reserve1 += msg.amount1;

        // change sqrtPrice, tick
    }

}