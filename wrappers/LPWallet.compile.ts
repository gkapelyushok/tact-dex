import { CompilerConfig } from '@ton/blueprint';

export const compile: CompilerConfig = {
    lang: 'tact',
    target: 'contracts/base-tact/lp_wallet.tact',
    options: {
        debug: true,
    },
};
