contract Position {
    ownerAddress: Address;
    tickLower: Int as int24;
    tickUpper: Int as int24;
    liquidity: Int as coins;
}