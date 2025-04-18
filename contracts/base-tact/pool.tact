import "./lp_account";
import "./messages";
import "./lp_wallet";
import "./gas";

contract Pool {
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

    init(
        routerAddress: Address,
        LPFee: Int,
        protocolFee: Int,
        refFee: Int,
        token0Address: Address,
        token1Address: Address,
        totalSupplyLP: Int,
        collectedToken0ProtocolFee: Int,
        collectedToken1ProtocolFee: Int,
        protocolFeeAddress: Address,
        reserve0: Int,
        reserve1: Int,
    ) {
        self.routerAddress = routerAddress;
        self.LPFee = LPFee;
        self.protocolFee = protocolFee;
        self.refFee = refFee;
        self.token0Address = token0Address;
        self.token1Address = token1Address;
        self.totalSupplyLP = totalSupplyLP;
        self.collectedToken0ProtocolFee = collectedToken0ProtocolFee;
        self.collectedToken1ProtocolFee = collectedToken1ProtocolFee;
        self.protocolFeeAddress = protocolFeeAddress;
        self.reserve0 = reserve0;
        self.reserve1 = reserve1;
    }

    receive(){}


    fun getAmountOut(hasRef: Bool, amountIn: Int, reserveIn: Int, reserveOut: Int): AmountOut {
        // let baseOut: Int = (amountIn * reserveOut) / (reserveIn + amountIn);
        let amountInWithFee: Int = amountIn * (FEE_DIVIDER - self.LPFee);
        let baseOut: Int = (amountInWithFee * reserveOut) / (reserveIn * FEE_DIVIDER + amountInWithFee);
        let protocolFeeOut: Int = 0;
        let refFeeOut: Int = 0;
        if (self.protocolFee > 0) {
            protocolFeeOut =  divc(baseOut * self.protocolFee, FEE_DIVIDER)
        }
        if (hasRef && (self.refFee > 0)) {
            refFeeOut = divc(baseOut * self.refFee, FEE_DIVIDER);
        }
        
        baseOut -= protocolFeeOut + refFeeOut;
                
        return AmountOut{
            out: baseOut,
            protocolFeeOut: protocolFeeOut,
            refFeeOut: refFeeOut
        };
    }

    receive(msg: JettonBurnNotification) {
        let gasRequired = getGasFee(25000, WORKCHAIN);
        let ctx = context();
        let msgValue = ctx.value;
        throwUnless(INSUFFICIENT_GAS, (msgValue > gasRequired) && (msgValue > ctx.readForwardFee()));
        let LPWalletAddress = contractAddress(getLPWalletStateInit(msg.sender, myAddress()));
        throwUnless(INVALID_CALLER, sender() == LPWalletAddress);
        throwUnless(ZERO_OUTPUT, msg.amount > 0);
        let amount0Out = (msg.amount * self.reserve0) / self.totalSupplyLP;
        let amount1Out = (msg.amount * self.reserve1) / self.totalSupplyLP;
        throwUnless(ZERO_OUTPUT, (amount0Out > 0) && (amount1Out > 0));
        self.reserve0 -= amount0Out;
        self.reserve1 -= amount1Out;
        self.totalSupplyLP -= msg.amount;
        
        let gas = 0;
        let mode = SendRemainingValue;
        if (msg.responseDestination != null) {
            gas = (msgValue - gasRequired) / 2;
            mode = SendDefaultMode;
            message(MessageParameters{
                to: msg.responseDestination!!,
                value: gas,
                mode: mode,
                bounce: false,
                body: JettonExcesses{
                    queryId: msg.queryId,
                }.toCell()
            });
        }
        message(MessageParameters{
            to: self.routerAddress,
            value: gas,
            mode: mode,
            bounce: false,
            body: PayTo{
                queryId: msg.queryId,
                toAddress: msg.sender,
                exitCode: BURN_OK,
                amount0Out: amount0Out,
                token0Address: self.token0Address,
                amount1Out: amount1Out,
                token1Address: self.token1Address,
            }.toCell()
        });
    }

    receive(msg: CbAddLiquidity) {
        let LPAccountStateInit: StateInit = getLPAccountStateInit(msg.userAddress, myAddress());
        let LPAccountAddress: Address = contractAddress(LPAccountStateInit);
        throwUnless(INVALID_CALLER, sender() == LPAccountAddress);

        let liquidity: Int = 0;
        let to: Address = emptyAddress(); 

        if (self.totalSupplyLP == 0) {
            liquidity = sqrt(msg.amount0 * msg.amount1) / REQUIRED_MIN_LIQUIDITY;
        } else {
            let toMint0 = (msg.amount0 * self.totalSupplyLP) / self.reserve0;
            let toMint1 = (msg.amount1 * self.totalSupplyLP) / self.reserve1;
            liquidity = min(toMint0, toMint1);
            to = msg.userAddress;
        }

        self.reserve0 += msg.amount0;
        self.reserve1 += msg.amount1;
        self.totalSupplyLP += liquidity;

        if ((liquidity < msg.minLPOut) || ((self.reserve0 > MAX_COINS) || (self.reserve1 > MAX_COINS))) {
            deploy(DeployParameters{
                init: LPAccountStateInit,
                value: 0,
                bounce: false,
                mode: SendRemainingValue,
                body: AddLiquidity {
                    queryId: msg.queryId,
                    newAmount0: msg.amount0,
                    newAmount1: msg.amount1,
                    minLPOut: 0,
                }.toCell()
            });
        } else {
            let LPWalletStateInit = getLPWalletStateInit(to, myAddress());
            deploy(DeployParameters{
                init: LPWalletStateInit,
                value: 0,
                mode: SendRemainingValue,
                bounce: false,
                body: JettonTransferInternal {
                    queryId: msg.queryId,
                    amount: liquidity,
                    sender: myAddress(),
                    responseDestination: to,
                    forwardTonAmount: 0,
                    forwardPayload: emptySlice(),
                }.toCell() 
            });
        }
    }

    receive(msg: CbRefundMe) {
        let lpAccountAddress = contractAddress(getLPAccountStateInit(msg.userAddress, myAddress()));
        throwUnless(INVALID_CALLER, lpAccountAddress == sender());
        message(MessageParameters{
            to: self.routerAddress,
            value: 0,
            mode: SendRemainingValue,
            bounce: false,
            body: PayTo{
                queryId: msg.queryId,
                toAddress: msg.userAddress,
                exitCode: REFUND_OK,
                amount0Out: msg.amount0,
                token0Address: self.token0Address,
                amount1Out: msg.amount1,
                token1Address: self.token1Address,
            }.toCell()
        });
    }

    receive(msg: Swap) {
        throwUnless(WRONG_CALLER, sender() == self.routerAddress);

        let refAddress: Address = emptyAddress();
        let tmpAmount0: Int = 0;
        let tmpAmount1: Int = 0;

        let mode = SendRemainingValue;
        let gas: Int = 0;

        let amountOut: AmountOut = AmountOut{out: 0, protocolFeeOut: 0, refFeeOut: 0};

        if (msg.hasRef) {
            mode = SendDefaultMode;
            gas = (context().value - getGasFee(25000, WORKCHAIN)) / 2;
            refAddress = msg.refAddress!!;
        }

        if (msg.tokenWallet == self.token0Address) {
            amountOut = self.getAmountOut(msg.hasRef, msg.jettonAmount, self.reserve0, self.reserve1);
            tmpAmount0 = msg.jettonAmount;
        } else {
            amountOut = self.getAmountOut(msg.hasRef, msg.jettonAmount, self.reserve1, self.reserve0);
            tmpAmount1 = msg.jettonAmount;
        }

        if ((self.totalSupplyLP <= 0) || (amountOut.out <= 0) || (msg.minOutput >= amountOut.out)) {
            message(MessageParameters{
                to: self.routerAddress,
                value: 0,
                mode: SendRemainingValue,
                bounce: false,
                body: PayTo{
                    queryId: msg.queryId,
                    toAddress: msg.fromRealUser,
                    exitCode: SWAP_REFUND_NO_LIQ,
                    amount0Out: tmpAmount0,
                    token0Address: self.token0Address,
                    amount1Out: tmpAmount1,
                    token1Address: self.token1Address,
                }.toCell()
            });
            return;
        }

        if (tmpAmount0 > 0) {
            self.reserve0 += msg.jettonAmount;
            self.reserve1 -= (amountOut.out + amountOut.protocolFeeOut + amountOut.refFeeOut);
            self.collectedToken1ProtocolFee += amountOut.protocolFeeOut;

            if ((self.reserve0 > MAX_COINS) || (self.reserve1 <= 0)) {
                message(MessageParameters{
                    to: self.routerAddress,
                    value: 0,
                    mode: SendRemainingValue,
                    bounce: false,
                    body: PayTo{
                        queryId: msg.queryId,
                        toAddress: msg.fromRealUser,
                        exitCode: SWAP_REFUND_RESERVE_ERR,
                        amount0Out: tmpAmount0,
                        token0Address: self.token0Address,
                        amount1Out: tmpAmount1,
                        token1Address: self.token1Address,
                    }.toCell()
                });
                return;
            }
            if (mode == SendDefaultMode) {
                message(MessageParameters{
                    to: self.routerAddress,
                    value: gas,
                    mode: mode,
                    bounce: false,
                    body: PayTo{
                        queryId: msg.queryId,
                        toAddress: msg.refAddress!!,
                        exitCode: SWAP_OK_REF,
                        amount0Out: 0,
                        token0Address: self.token0Address,
                        amount1Out: amountOut.refFeeOut,
                        token1Address: self.token1Address,
                    }.toCell()
                });
            }
            message(MessageParameters{
                to: self.routerAddress,
                value: gas,
                mode: mode,
                bounce: false,
                body: PayTo{
                    queryId: msg.queryId,
                    toAddress: msg.fromAddress,
                    exitCode: SWAP_OK,
                    amount0Out: 0,
                    token0Address: self.token0Address,
                    amount1Out: amountOut.out,
                    token1Address: self.token1Address,
                }.toCell()
            });
        } else {
            self.reserve1 += msg.jettonAmount;
            self.reserve0 -= (amountOut.out + amountOut.protocolFeeOut + amountOut.refFeeOut);
            self.collectedToken0ProtocolFee += amountOut.protocolFeeOut;

            if ((self.reserve1 > MAX_COINS) || (self.reserve0 <= 0)) {
                message(MessageParameters{
                    to: self.routerAddress,
                    value: 0,
                    mode: SendRemainingValue,
                    bounce: false,
                    body: PayTo{
                        queryId: msg.queryId,
                        toAddress: msg.fromRealUser,
                        exitCode: SWAP_REFUND_RESERVE_ERR,
                        amount0Out: tmpAmount0,
                        token0Address: self.token0Address,
                        amount1Out: tmpAmount1,
                        token1Address: self.token1Address,
                    }.toCell()
                });
                return;
            }

            if (mode == SendDefaultMode) {
                message(MessageParameters{
                    to: self.routerAddress,
                    value: gas,
                    mode: mode,
                    bounce: false,
                    body: PayTo{
                        queryId: msg.queryId,
                        toAddress: msg.refAddress!!,
                        exitCode: SWAP_OK_REF,
                        amount0Out: amountOut.refFeeOut,
                        token0Address: self.token0Address,
                        amount1Out: 0,
                        token1Address: self.token1Address,
                    }.toCell()
                });
            }
            message(MessageParameters{
                to: self.routerAddress,
                value: gas,
                mode: mode,
                bounce: false,
                body: PayTo{
                    queryId: msg.queryId,
                    toAddress: msg.fromAddress,
                    exitCode: SWAP_OK,
                    amount0Out: amountOut.out,
                    token0Address: self.token0Address,
                    amount1Out: 0,
                    token1Address: self.token1Address,
                }.toCell()
            });
        }
    }

    receive(msg: ProvideLP) {
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
                minLPOut: msg.minLPOut,
            }.toCell()
        }); 
    }


    receive(msg: UserCollectFees) {
        throwUnless(NO_LIQUIDITY, self.totalSupplyLP > REQUIRED_MIN_LIQUIDITY);
        throwUnless(LOW_LIQUIDITY, (self.collectedToken0ProtocolFee > REQUIRED_MIN_COLLECT_FEES) &&
                                   (self.collectedToken1ProtocolFee > REQUIRED_MIN_COLLECT_FEES));
        throwUnless(INVALID_RECIPIENT, self.protocolFeeAddress != HOLE_ADDRESS);
        let msgValue = context().value;
        let gasRequired = getGasFee(40000, WORKCHAIN);
        throwUnless(INSUFFICIENT_GAS, (msgValue - gasRequired) > 1000000000); // 1 ton
        let gas = (msgValue - gasRequired) / 4;
        let reward0 = self.collectedToken0ProtocolFee / 1000;
        let reward1 = self.collectedToken1ProtocolFee / 1000;
        self.collectedToken0ProtocolFee -= reward0;
        self.collectedToken1ProtocolFee -= reward1;

        throwUnless(ZERO_OUTPUT, (reward0 > 0) && (reward1 > 0));
        throwUnless(ZERO_OUTPUT, (self.collectedToken0ProtocolFee > 0) && 
                                 (self.collectedToken1ProtocolFee > 0));

        message(MessageParameters{
            to: self.routerAddress,
            value: gas * 3,
            mode: SendDefaultMode,
            bounce: true,
            body: PayTo {
                queryId: msg.queryId,
                toAddress: self.protocolFeeAddress,
                exitCode: 0,
                amount0Out: self.collectedToken0ProtocolFee,
                token0Address: self.token0Address,
                amount1Out: self.collectedToken1ProtocolFee,
                token1Address: self.token1Address,
            }.toCell(),
        });

        message(MessageParameters{
            to: self.routerAddress,
            value: gas,
            mode: SendDefaultMode,
            bounce: true,
            body: PayTo {
                queryId: msg.queryId,
                toAddress: sender(),
                exitCode: 0,
                amount0Out: reward0,
                token0Address: self.token0Address,
                amount1Out: reward1,
                token1Address: self.token1Address,
            }.toCell(),
        });

        self.collectedToken0ProtocolFee = 0;
        self.collectedToken1ProtocolFee = 0;

    }

    receive(msg: RouterCollectFees) {
        throwUnless(WRONG_CALLER, sender() == self.routerAddress);
        throwUnless(NO_LIQUIDITY, (self.collectedToken0ProtocolFee > 0) &&
                                  (self.collectedToken1ProtocolFee > 0));
        throwUnless(INVALID_RECIPIENT, self.protocolFeeAddress != HOLE_ADDRESS);
        
        message(MessageParameters{
            to: self.routerAddress,
            value: 0,
            mode: SendRemainingValue,
            bounce: true,
            body: PayTo {
                queryId: msg.queryId,
                toAddress: self.protocolFeeAddress,
                exitCode: 0,
                amount0Out: self.collectedToken0ProtocolFee,
                token0Address: self.token0Address,
                amount1Out: self.collectedToken1ProtocolFee,
                token1Address: self.token1Address,
            }.toCell(),
        });

        self.collectedToken0ProtocolFee = 0;
        self.collectedToken1ProtocolFee = 0;
    }

    receive(msg: PoolSetFees) {
        throwUnless(WRONG_CALLER, sender() == self.routerAddress);
        throwUnless(FEE_OUT_OF_RANGE, (MIN_FEE) <= msg.newLPFee && msg.newLPFee <= MAX_FEE);
        throwUnless(FEE_OUT_OF_RANGE, (MIN_FEE) <= msg.newProtocolFee && msg.newProtocolFee <= MAX_FEE);
        throwUnless(FEE_OUT_OF_RANGE, (MIN_FEE) <= msg.newRefFee && msg.newRefFee <= MAX_FEE);

        self.LPFee = msg.newLPFee;
        self.protocolFee = msg.newProtocolFee;
        self.refFee = msg.newRefFee;
        self.protocolFeeAddress = msg.newProtocolFeeAddress;
    }

    get fun getPoolData(): PoolData {
        return PoolData{
            routerAddress: self.routerAddress,
            LPFee: self.LPFee,
            protocolFee: self.protocolFee,
            refFee: self.refFee,
            token0Address: self.token0Address,
            token1Address: self.token1Address,
            totalSupplyLP: self.totalSupplyLP,
            collectedToken0ProtocolFee: self.collectedToken0ProtocolFee,
            collectedToken1ProtocolFee: self.collectedToken1ProtocolFee,
            protocolFeeAddress: self.protocolFeeAddress,
            reserve0: self.reserve0,
            reserve1: self.reserve1,
        }
    }

    get fun getExpectedOutputs(amount: Int, tokenWallet: Address): AmountOut {
        throwUnless(NO_LIQUIDITY, self.totalSupplyLP > REQUIRED_MIN_LIQUIDITY);
        let amountOut: AmountOut = AmountOut{
            out: 0,
            protocolFeeOut: 0,
            refFeeOut: 0,
        };
        let ok: Bool = false;
        if (tokenWallet == self.token0Address) {
            ok = true;
            amountOut = self.getAmountOut(false, amount, self.reserve0, self.reserve1);
        }
        if (tokenWallet == self.token1Address) {
            ok = true;
            amountOut = self.getAmountOut(false, amount, self.reserve1, self.reserve0);
        }
        throwUnless(INVALID_TOKEN, ok);
        return amountOut;
    }

    get fun getLPAccountAddress(userAddress: Address): Address {
        return contractAddress(getLPAccountStateInit(userAddress, myAddress()));
    }

    get fun getExpectedTokens(amount0: Int, amount1: Int): Int {
        let toMint0 = (amount1 * self.totalSupplyLP) / self.reserve0;
        let toMint1 = (amount0 * self.totalSupplyLP) / self.reserve1;

        return min(toMint0, toMint1);
    }

    get fun getExpectedLiquidity(jettonAmount: Int): Amounts  {
        return Amounts{
            amount0: (jettonAmount * self.reserve0) / self.totalSupplyLP,
            amount1: (jettonAmount * self.reserve1) / self.totalSupplyLP,
        };         
    }
}

inline fun getLPAccountStateInit(userAddress: Address, poolAddress: Address): StateInit {
    return initOf LPAccount(
        userAddress,
        poolAddress,
        0,
        0
    );
}

inline fun getLPWalletStateInit(owner: Address, minter: Address): StateInit {
    return initOf JettonWallet(
        0,
        owner,
        minter,
    );
}