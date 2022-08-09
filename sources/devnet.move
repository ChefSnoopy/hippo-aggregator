module hippo_aggregator::devnet {

    public entry fun mock_deploy_pontem(admin: &signer) {
        use hippo_swap::mock_coin;
        use pontem::scripts;
        let btc = mock_coin::mint<mock_coin::WBTC>(100000000 * 1000);
        let usdc = mock_coin::mint<mock_coin::WUSDC>(100000000 * 10000000);
        scripts::register_pool_and_add_liquidity<mock_coin::WBTC, mock_coin::WUSDC, >()
    }
}
