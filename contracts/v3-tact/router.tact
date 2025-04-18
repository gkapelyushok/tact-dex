contract Router {
    receive(msg: JettonNotification) {
        throwUnless(INVALID_AMOUNT, msg.amount > 0);
        let payload: Slice = msg.forwardPayload;
        let opcode: Int = payload.loadUint(32);
        let token1Address: Address = payload.loadAddress();
        let ctx: Context = context();
        let fwdFee = ctx.readForwardFee();
        if ((fwdFee * 6 > ctx.value) || token1Address == ctx.sender || self.isLocked) {
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
                    }.toCell()
                });
            } else if (opcode == PROVIDE_LP) {
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
                            lowerTick: lowerTick,
                            upperTick: upperTick,
                            amount0: 0,
                            amount1: msg.amount,
                        }.toCell()
                    }); 
                }  
            }
        }
    }
}