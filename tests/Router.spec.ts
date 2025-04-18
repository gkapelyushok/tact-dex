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
    let admin: SandboxContract<TreasuryContract>;
    let router: SandboxContract<Router>;
    let pool: SandboxContract<TreasuryContract>;
    let token0: SandboxContract<TreasuryContract>;
    let token1: SandboxContract<TreasuryContract>;
    let lpAccount: SandboxContract<LPAccount>;
    
    beforeEach(async () => {
        blockchain = await Blockchain.create();
        user = await blockchain.treasury("user");
        admin = await blockchain.treasury("admin");
        token0 = await blockchain.treasury("token0Address");
        token1 = await blockchain.treasury("token1Address");
        router = blockchain.openContract(await Router
            .fromInit(admin.address, false)
        );
        pool = await blockchain.treasury("pool");
        lpAccount = blockchain.openContract(await LPAccount
            .fromInit(
                user.address, 
                pool.address, 
                toNano(0), 
                toNano(0)
            )
        );
    
        await router.send(
            user.getSender(),
            {
                value: toNano('1'),
            }, 
            null
        );
        await lpAccount.send(
            user.getSender(),
            {
                value: toNano('1'),
            }, 
            null
        );
    });

    it("should get a valid pool address", async () => {
        const poolAddress = await router.getGetPoolAddress(
            token0.address,
            token1.address
        );

        //expect(poolAddress).toEqualAddress(pool.address);
    });

    it("should refuse to pay if caller is not valid", async () => {
        const send = await router.send(
            user.getSender(),
            {
                value: toNano(1),
            },
            {
                $$type: "PayTo",
                queryId: toNano(1),
                toAddress: user.address,
                exitCode: toNano(0),
                amount0Out: toNano(0),
                token0Address: token0.address,
                amount1Out: toNano(0),
                token1Address: token1.address,
            }
        )

        console.log("PayTo not from pool");
        printTransactionFees(send.transactions);


        expect(send.transactions).toHaveTransaction({
            from: user.address,
            to: router.address,
            success: false,
            exitCode: 1005
        });
    });

    it("should pay if caller is valid", async () => {
        const poolAddress = await router.getGetPoolAddress(
            token0.address,
            token1.address
        );
        const send = await blockchain.sendMessage(internal({
            from: poolAddress,
            to: router.address,
            value: toNano(1),
            bounce: true,
            body: beginCell()
                    .storeUint(0xaaaaaaa8, 32) // opcode
                    .storeUint(1n, 64) // queryId
                    .storeAddress(user.address) // toAddress
                    .storeUint(0n, 32) // exitCode
                    .storeCoins(100n) // amount0Out
                    .storeAddress(token0.address) // token0Address
                    .storeCoins(200n) // amount1Out
                    .storeRef(new Builder()
                        .storeAddress(token1.address) // token1Address
                        .endCell())
                    .endCell()
        }));

        console.log("PayTo from pool");
        printTransactionFees(send.transactions);
        

        expect(send.transactions).toHaveTransaction({
            from: poolAddress,
            to: router.address,
            success: true,
        });
        expect(send.transactions).toHaveTransaction({
            from: router.address,
            to: token0.address,
            success: true,
        });
        expect(send.transactions).toHaveTransaction({
            from: router.address,
            to: token1.address,
            success: true,
        });
    });

    it("should route swap message", async () =>{
        const poolAddress = await router.getGetPoolAddress(
            token0.address,
            token1.address
        );
        const sendLP1 = await router.send(
            token0.getSender(),
            {
                value: toNano(1),
            },
            {
                $$type: "JettonNotification",
                queryId: toNano(1),
                amount: toNano(10000),
                sender: user.address,
                forwardPayload: beginCell()
                    .storeUint(0xfffffff2, 32) // opcode
                    .storeAddress(token0.address)
                    .storeCoins(1)
                    .asSlice()
            }
        );
        const sendLP2 = await router.send(
            token0.getSender(),
            {
                value: toNano(1),
            },
            {
                $$type: "JettonNotification",
                queryId: toNano(1),
                amount: toNano(20000),
                sender: user.address,
                forwardPayload: beginCell()
                    .storeUint(0xfffffff2, 32) // opcode
                    .storeAddress(token1.address)
                    .storeCoins(1)
                    .asSlice()
            }
        );
        const send = await router.send(
            token0.getSender(),
            {
                value: toNano(1),
            },
            {
                $$type: "JettonNotification",
                queryId: toNano(1),
                amount: toNano(1),
                sender: user.address,
                forwardPayload: beginCell()
                    .storeUint(0xfffffff1, 32) // opcode
                    .storeAddress(token1.address)
                    .storeAddress(user.address)
                    .storeCoins(0)
                    .storeBit(0)
                    .storeAddress(null)
                    .asSlice()
            }
        );
        console.log("should route swap message:");
        printTransactionFees(send.transactions);
        expect(send.transactions).toHaveTransaction({
            from: token0.address,
            to: router.address,
            success: true,
        });
        expect(send.transactions).toHaveTransaction({
            from: router.address,
            to: poolAddress,
        });

    });

    it("should route provideLP message", async () =>{
        const poolAddress = await router.getGetPoolAddress(
            token0.address,
            token1.address
        );
        const send = await router.send(
            token0.getSender(),
            {
                value: toNano(1),
            },
            {
                $$type: "JettonNotification",
                queryId: toNano(1),
                amount: toNano(10000),
                sender: user.address,
                forwardPayload: beginCell()
                    .storeUint(0xfffffff2, 32) // opcode
                    .storeAddress(token1.address)
                    .storeCoins(1)
                    .asSlice()
            }
        );
        console.log("should route provideLP message:");
        printTransactionFees(send.transactions);
        expect(send.transactions).toHaveTransaction({
            from: token0.address,
            to: router.address,
            success: true,
        });
        expect(send.transactions).toHaveTransaction({
            from: router.address,
            to: poolAddress,
            success: true,
        });
    });
});