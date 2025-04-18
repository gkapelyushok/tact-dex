import { toNano, beginCell } from '@ton/core';
import { Router } from '../build/Router/tact_Router';
import { NetworkProvider } from '@ton/blueprint';

export async function run(provider: NetworkProvider) {
 
    const router = provider.open(
        await Router.fromInit(provider.sender().address!!, false)
    );

    await router.send(
        provider.sender(),
        {
            value: toNano('1')
        },
        null
    )

    await provider.waitForDeploy(router.address);
}