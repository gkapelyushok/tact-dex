import { Blockchain, internal, printTransactionFees, SandboxContract, TreasuryContract } from '@ton/sandbox';
import { beginCell, Builder, toNano } from '@ton/core';
import '@ton/test-utils';
import { Router } from '../wrappers/Router';
import { Pool } from '../wrappers/Pool';
import { LPAccount } from '../wrappers/LPAccount';
import { PayTo } from '../wrappers/Router';


describe('Router', () => {
    let blockchain: Blockchain;
    let user: SandboxContract<TreasuryContract>;
    let router: SandboxContract<TreasuryContract>;
    let pool: SandboxContract<Pool>;
    let token0: SandboxContract<TreasuryContract>;
    let token1: SandboxContract<TreasuryContract>;
    let lpAccount: SandboxContract<LPAccount>;
    

    beforeEach(async () => {
        blockchain = await Blockchain.create();
        user = await blockchain.treasury("user");
        token0 = await blockchain.treasury("token0Address");
        token1 = await blockchain.treasury("token1Address");
        router = await blockchain.treasury("router");
        pool = blockchain.openContract(await Pool
            .fromInit(
                router.address,
                20n,
                0n,
                10n, 
                token0.address, 
                token1.address, 
                0n, 
                0n, 
                0n,
                user.address,
                0n,
                0n
            )
        );
        lpAccount = blockchain.openContract(await LPAccount
            .fromInit(
                user.address, 
                pool.address, 
                toNano(0), 
                toNano(0)
            )
        );
        await pool.send(
            user.getSender(),
            {
                value: toNano('1'),
            }, 
            null
        )
        await lpAccount.send(
            user.getSender(),
            {
                value: toNano('1'),
            }, 
            null
        )
    });

    it("should accept ProvideLP message", async () => {
        const send = await pool.send(
            router.getSender(),
            {
                value: toNano(1)
            },
            {
                $$type: "ProvideLP",
                queryId: toNano(1),
                fromUser: user.address,
                minLPOut: toNano(1),
                amount0: toNano(1000),
                amount1: toNano(0)
            }   
        );
        console.log("should accept ProvideLP message 1");

        printTransactionFees(send.transactions);

        expect(send.transactions).toHaveTransaction({
            from: pool.address,
            to: lpAccount.address,
            success: true,
        });

        const send1 = await pool.send(
            router.getSender(),
            {
                value: toNano(1)
            },
            {
                $$type: "ProvideLP",
                queryId: toNano(1),
                fromUser: user.address,
                minLPOut: toNano(1),
                amount0: toNano(0),
                amount1: toNano(1000)
            }   
        );

        console.log("should accept ProvideLP message 2");
        printTransactionFees(send1.transactions);

        expect(send1.transactions).toHaveTransaction({
            from: pool.address,
            to: lpAccount.address,
            success: true,
        });

    });

    it("should accept Swap message", async () => {
        const send = await pool.send(
            router.getSender(),
            {
                value: toNano(1)
            },
            {
                $$type: "Swap",
                queryId: toNano(0),
                fromAddress: user.address,
                tokenWallet: token1.address,
                jettonAmount: toNano(200000),
                minOutput: toNano(200),
                hasRef: false,
                fromRealUser: user.address,
                refAddress: null
            }  
        )
        console.log("should accept Swap message 1");
        printTransactionFees(send.transactions);

        expect(send.transactions).toHaveTransaction({
            from: router.address,
            to: pool.address,
            success: true,
        });
    });


});
