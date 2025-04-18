import { CompilerConfig } from '@ton/blueprint';

export const compile: CompilerConfig = {
    lang: 'tact',
    target: 'contracts/base-tact/pool.tact',
    options: {
        debug: true,
    },
};
