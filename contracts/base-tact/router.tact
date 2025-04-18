import "./pool";
import "./messages";

contract Router {
    isLocked: Bool;
    adminAddress: Address;

    init(adminAddress: Address, isLocked: Bool){
        self.adminAddress = adminAddress;
        self.isLocked = isLocked;
    }

    receive() {}

    receive(msg: PayTo) {
        let gasRequired = getGasFee(20000, WORKCHAIN); 
        let msgValue = context().value;
        throwUnless(INSUFFICIENT_GAS, msgValue > gasRequired);

        let poolAddress = getPoolAddress(msg.token0Address, msg.token1Address);
        throwUnless(INVALID_CALLER, poolAddress == sender());

        let gas = 0;
        let mode = SendRemainingValue;
        if ((msg.amount0Out > 0) && (msg.amount1Out > 0)) {
            gas = (msgValue - gasRequired) / 2;
            // gas = msgValue / 2;
            mode = SendDefaultMode;
        }
        if (msg.amount0Out > 0) {
            message(MessageParameters{
                to: msg.token0Address,
                value: gas,
                mode: mode,
                bounce: false,
                body: JettonTransfer {
                    queryId: msg.queryId,
                    amount: msg.amount0Out,
                    destination: msg.toAddress,
                    responseDestination: msg.toAddress,
                    customPayload: null,
                    forwardTonAmount: 0,
                    forwardPayload: emptySlice(),
                }.toCell()
            });
        }
        if (msg.amount1Out > 0) {
            message(MessageParameters{
                to: msg.token1Address,
                value: gas,
                mode: mode,
                bounce: false, 
                body: JettonTransfer {
                    queryId: msg.queryId,
                    amount: msg.amount1Out,
                    destination: msg.toAddress,
                    responseDestination: msg.toAddress,
                    customPayload: null,
                    forwardTonAmount: 0,
                    forwardPayload: emptySlice(),
                }.toCell()
            });
        }
    }

    receive(msg: JettonNotification) {
        throwUnless(INVALID_AMOUNT, msg.amount > 0);
        let payload: Slice = msg.forwardPayload;
        let opcode: Int = payload.loadUint(32);
        let token1Address: Address = payload.loadAddress();
        let ctx: Context = context();
        let fwdFee = ctx.readForwardFee();
        if ((fwdFee * 6 > ctx.value) || token1Address == ctx.sender || self.isLocked) {
            // let exitCode: Slice as remaining = "";
            // if (self.isLocked) {
            //     exitCode = transfer_bounce_locked;
            // } else {
            //     exitCode = transfer_bounce_invalid_request;
            // }
            message(MessageParameters{
                to: ctx.sender,
                value: 0,
                mode: SendRemainingValue,
                bounce: false,
                body: JettonTransfer {
                    queryId: msg.queryId,
                    amount: msg.amount,
                    destination: ctx.sender,
                    responseDestination: ctx.sender,
                    customPayload: null, // .store_uint(0, 1);
                    forwardTonAmount: 0,
                    forwardPayload: emptySlice(), // .store_uint(0, 1);
                }.toCell()
            });
        } else {
            if (opcode == SWAP) {
                let toAddress: Address = payload.loadAddress();
                let minOutput: Int = payload.loadCoins(); 
                let hasRef: Bool = payload.loadUint(1) == 1;  

                let poolAddress: Address = getPoolAddress(ctx.sender, token1Address);
                message(MessageParameters{
                    to: poolAddress,
                    value: 0,
                    mode: SendRemainingValue,
                    bounce: false,
                    body: Swap {
                        queryId: msg.queryId,
                        fromAddress: toAddress,
                        tokenWallet: ctx.sender,
                        jettonAmount: msg.amount,
                        minOutput: minOutput,
                        hasRef: hasRef,
                        fromRealUser: msg.sender,
                        refAddress: hasRef ? payload.loadAddress() : null,
                    }.toCell()
                });
            } else if (opcode == PROVIDE_LP) {
                let minLPOut: Int = payload.loadCoins();
                let poolInit: StateInit = getPoolStateInit(ctx.sender, token1Address);
                if (ctx.sender.asSlice().hash() > token1Address.asSlice().hash()) {
                    deploy(DeployParameters{
                        init: poolInit,
                        value: 0,
                        mode: SendRemainingValue,
                        bounce: false,
                        body: ProvideLP {
                            queryId: msg.queryId,
                            fromUser: msg.sender,
                            minLPOut: minLPOut,
                            amount0: msg.amount, 
                            amount1: 0,
                        }.toCell()
                    }); 
                } else {
                    deploy(DeployParameters{
                        init: poolInit,
                        value: 0,
                        mode: SendRemainingValue,
                        bounce: false,
                        body: ProvideLP {
                            queryId: msg.queryId,
                            fromUser: msg.sender,
                            minLPOut: minLPOut,
                            amount0: 0,
                            amount1: msg.amount,
                        }.toCell()
                    }); 
                }  
            }
        }
    }  
    

    receive(msg: RouterSetFees) {
        throwUnless(INVALID_CALLER, sender() == self.adminAddress);
        let poolAddress = getPoolAddress(msg.token0Address, msg.token1Address);
        message(MessageParameters{
            to: poolAddress,
            value: 0,
            mode: SendRemainingValue,
            bounce: false,
            body: PoolSetFees {
                queryId: msg.queryId,
                newLPFee: msg.newLPFee,
                newProtocolFee: msg.newProtocolFee,
                newRefFee: msg.newRefFee,
                newProtocolFeeAddress: msg.newProtocolFeeAddress,
            }.toCell(),
        });
    }

    receive(msg: RouterCollectFees) {
        throwUnless(INVALID_CALLER, sender() == self.adminAddress);
        let poolAddress = getPoolAddress(msg.token0Address, msg.token1Address);
        message(MessageParameters{
            to: poolAddress,
            value: 0,
            mode: SendRemainingValue,
            bounce: false,
            body: PoolCollectFees {
                queryId: msg.queryId,
            }.toCell(),
        });
    }

    receive(msg: Lock) {
        throwUnless(INVALID_CALLER, sender() == self.adminAddress);
        self.isLocked = true;
    }
    
    receive(msg: Unlock) {
        throwUnless(INVALID_CALLER, sender() == self.adminAddress);
        self.isLocked = false;
    }

    
    receive(msg: ResetGas) {
        throwUnless(INVALID_CALLER, sender() == self.adminAddress);
        message(MessageParameters{
             to: self.adminAddress,
             value: myBalance() - REQUIRED_TON_RESERVE,
             mode: SendDefaultMode,
             bounce: false,
     });
    }
    
    receive(msg: ResetPoolGas) {
        throwUnless(INVALID_CALLER, sender() == self.adminAddress);
        let poolAddress = getPoolAddress(msg.token0Address, msg.token1Address);
        message(MessageParameters{
            to: poolAddress,
            value: 0,
            mode: SendRemainingValue,
            bounce: false,
            body: ResetGas {
                queryId: msg.queryId,
            }.toCell(),
        });
    }


    get fun getPoolAddress(token0Address: Address, token1Address: Address): Address {
        return getPoolAddress(token0Address, token1Address)
    }
}

inline fun getPoolStateInit(token0Address: Address, token1Address: Address): StateInit {
    if (token0Address.asSlice().hash() > token1Address.asSlice().hash()) {
        return initOf Pool(
            myAddress(), // routerAddress
            20,           // lp_fee
            10,           // protocolFee
            10,           // ref_fee
            token0Address, // token0Address
            token1Address, // token1Address
            0,           // totalSupplyLP
            0,           // collected_token0_protocol_fee
            0,           // collected_token1_protocol_fee
            HOLE_ADDRESS,           // protocol_fee_address
            0,           // reserve0
            0,           // reserve1
        );
    } else {
        return initOf Pool(
            myAddress(), // routerAddress
            20,           // lp_fee
            10,           // protocolFee
            10,           // ref_fee
            token1Address, // token0Address
            token0Address, // token1Address
            0,           // totalSupplyLP
            0,           // collected_token0_protocol_fee
            0,           // collected_token1_protocol_fee
            HOLE_ADDRESS,           // protocol_fee_address
            0,           // reserve0
            0,           // reserve1
        );
    }
}

inline fun getPoolAddress(token0Address: Address, token1Address: Address): Address {
    return contractAddress(getPoolStateInit(token0Address, token1Address));
}