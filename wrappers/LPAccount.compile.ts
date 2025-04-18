import { CompilerConfig } from '@ton/blueprint';

export const compile: CompilerConfig = {
    lang: 'tact',
    target: 'contracts/base-tact/lp_account.tact',
    options: {
        debug: true,
    },
};
