import "./messages";

contract LPAccount {
    userAddress: Address;
    poolAddress: Address;
    amount0: Int as coins;
    amount1: Int as coins;

    init(userAddress: Address, poolAddress: Address, amount0: Int, amount1: Int) {
        self.userAddress = userAddress;
        self.poolAddress = poolAddress;
        self.amount0 = amount0;
        self.amount1 = amount1;
    }
    
    receive(){}

    receive(msg: AddLiquidity) {
        throwUnless(INVALID_CALLER, sender() == self.poolAddress);
        self.amount0 += msg.newAmount0;
        self.amount1 += msg.newAmount1;
        if ((msg.minLPOut > 0) && (self.amount0 > 1000) && (self.amount1 > 1000)){
            message(MessageParameters {
                to: self.poolAddress,
                value: 0,
                mode: SendRemainingValue,
                bounce: false,
                body: CbAddLiquidity {
                    queryId: msg.queryId,
                    amount0: self.amount0,
                    amount1: self.amount1,
                    userAddress: self.userAddress,
                    minLPOut: msg.minLPOut
                }.toCell()
            });
            self.amount0 = 0;
            self.amount1 = 0;
        }   
    }

    receive(msg: RefundMe) {
        throwUnless(WRONG_OP, sender() == self.userAddress);
        throwUnless(NO_LIQUIDITY, (self.amount0 > 0) || (self.amount1 > 0));
        message(MessageParameters {
            to: self.poolAddress,
            value: 0, 
            mode: SendRemainingValue,
            bounce: false,
            body: CbRefundMe {
                queryId: msg.queryId,
                amount0: self.amount0,
                amount1: self.amount1,
                userAddress: self.userAddress
            }.toCell()
        });

        self.amount0 = 0;
        self.amount1 = 0;
    }

    receive(msg: DirectAddLiquidity) {
        throwUnless(WRONG_OP, sender() == self.userAddress);
        throwUnless(ZERO_OUTPUT, (msg.minLPOut > 0) && (self.amount0 > 1000) && (self.amount1 > 1000));
        self.amount0 -= msg.amount0;
        self.amount1 -= msg.amount1;
        throwUnless(NO_LIQUIDITY, (self.amount0 >= 0) && (self.amount1 >= 0));
        message(MessageParameters {
            to: self.poolAddress,
            value: 0,
            mode: SendRemainingValue,
            bounce: false,
            body: CbAddLiquidity {
                queryId: msg.queryId,
                amount0: msg.amount0,
                amount1: msg.amount1,
                userAddress: self.userAddress,
                minLPOut: msg.minLPOut,
            }.toCell()
        });
    }

    // receive(msg: ResetGas) {}

    get fun getLPAccountData(): LPAccountData {
        return LPAccountData{
            userAddress: self.userAddress,
            poolAddress: self.poolAddress,
            amount0: self.amount0,
            amount1: self.amount1,
        }
    }
}