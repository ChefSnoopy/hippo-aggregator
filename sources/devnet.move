module hippo_aggregator::devnetv6{
    use hippo_swap::mock_coin::{WBTC, WUSDC, faucet_mint_to};
    use std::signer::address_of;

    const BTC_AMOUNT: u64 = 100000000 * 1000;
    const USDC_AMOUNT: u64 = 100000000 * 1000 * 10000;

    struct PontemLP<phantom X, phantom Y> {}

    #[cmd(desc=b"Create BTC-USDC pool on pontem and add liquidity")]
    public entry fun mock_deploy_pontem(admin: signer) {
        use pontem::scripts;
        faucet_mint_to<WBTC>(&admin, BTC_AMOUNT);
        faucet_mint_to<WUSDC>(&admin, USDC_AMOUNT);
        scripts::register_pool_and_add_liquidity<WBTC, WUSDC, PontemLP<WBTC, WUSDC>>(
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
        use econia::registry::E0;
        market::register_market<WBTC, WUSDC, E0>(&admin);
        user::register_market_account<WBTC, WUSDC, E0>(&admin, 0);
        faucet_mint_to<WBTC>(&admin, BTC_AMOUNT);
        faucet_mint_to<WUSDC>(&admin, USDC_AMOUNT);
        user::deposit_collateral_coinstore<WBTC, WUSDC, E0>(&admin, 0, true, BTC_AMOUNT);
        user::deposit_collateral_coinstore<WBTC, WUSDC, E0>(&admin, 0, false, USDC_AMOUNT);
        market::place_limit_order_user<WBTC, WUSDC, E0>(&admin, address_of(&admin), true, BTC_AMOUNT, 10001);
        market::place_limit_order_user<WBTC, WUSDC, E0>(&admin, address_of(&admin), false, BTC_AMOUNT, 10000);
    }
}
