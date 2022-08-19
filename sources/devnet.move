module hippo_aggregator::devnetv6{
    use coin_list::devnet_coins::{DevnetBTC as BTC, DevnetUSDC as USDC, mint_to_wallet};
    use std::signer::address_of;
    use econia::registry::E0;

    const BTC_AMOUNT: u64 = 100000000 * 1000;
    const USDC_AMOUNT: u64 = 100000000 * 1000 * 10000;

    struct PontemLP<phantom X, phantom Y> {}

    #[cmd(desc=b"Create BTC-USDC pool on pontem and add liquidity")]
    public entry fun mock_deploy_pontem(admin: signer) {
        use pontem::scripts;
        mint_to_wallet<BTC>(&admin, BTC_AMOUNT);
        mint_to_wallet<USDC>(&admin, USDC_AMOUNT);
        scripts::register_pool_and_add_liquidity<BTC, USDC, PontemLP<BTC, USDC>>(
            admin,
            2, // uncorrelated,
            BTC_AMOUNT,
            0,
            USDC_AMOUNT,
            0
        )
    }

    #[cmd(desc=b"Create BTC-USDC pool on econia and add liquidity")]
    public entry fun mock_deploy_econia(admin: signer) {
        use econia::market;
        use econia::user;
        market::register_market<BTC, USDC, E0>(&admin);
        user::register_market_account<BTC, USDC, E0>(&admin, 0);
        mint_to_wallet<BTC>(&admin, BTC_AMOUNT);
        mint_to_wallet<USDC>(&admin, USDC_AMOUNT);
        user::deposit_collateral_coinstore<BTC, USDC, E0>(&admin, 0, true, BTC_AMOUNT);
        user::deposit_collateral_coinstore<BTC, USDC, E0>(&admin, 0, false, USDC_AMOUNT);
        market::place_limit_order_user<BTC, USDC, E0>(&admin, address_of(&admin), true, BTC_AMOUNT, 10001);
        market::place_limit_order_user<BTC, USDC, E0>(&admin, address_of(&admin), false, BTC_AMOUNT, 10000);
    }
}
