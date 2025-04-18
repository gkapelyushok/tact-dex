import { CompilerConfig } from '@ton/blueprint';

export const compile: CompilerConfig = {
    lang: 'tact',
    target: 'contracts/helloworld.tact',
    options: {
        debug: true,
    },
};
