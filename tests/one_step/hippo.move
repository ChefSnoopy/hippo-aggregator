#[test_only]
module hippo_aggregator::hippo {
    use std::debug;
    use std::signer;
    use aptos_framework::aptos_account;
    use aptos_framework::coin;
    use aptos_framework::genesis;

    use hippo_aggregator::aggregatorv6::{one_step_route, initialize};
    use econia::registry::E1;
    use hippo_swap::cp_scripts;

    use coin_list::devnet_coins;
    use coin_list::devnet_coins::{
        DevnetBTC as BTC,
        DevnetUSDC as USDC
    };

    #[test_only]
    const DEX_HIPPO: u8 = 1;
    #[test_only]
    const DEX_ECONIA: u8 = 2;
    #[test_only]
    const HIPPO_CONSTANT_PRODUCT:u8 = 1;


    #[test(aggregator = @hippo_aggregator, hippo_swap = @hippo_swap, coin_list_admin = @coin_list, user=@0x2)]
    fun test_one_step_hippo(aggregator: &signer, hippo_swap: &signer, coin_list_admin: &signer, user: &signer){
        genesis::setup();
        aptos_account::create_account(signer::address_of(aggregator));
        initialize(aggregator);
        if (signer::address_of(hippo_swap) != signer::address_of(aggregator)) {
            aptos_account::create_account(signer::address_of(hippo_swap));
        };
        devnet_coins::deploy(coin_list_admin);
        // hippo-swap cp swap pool
        // btc-usdt btc-usdc
        cp_scripts::mock_deploy_script(hippo_swap);
        let btc_amount = 100;
        devnet_coins::mint_to_wallet<BTC>(user, btc_amount);

        let user_addr = signer::address_of(user);
        assert!(coin::balance<BTC>(user_addr) == btc_amount, 0);
        one_step_route<BTC, USDC, E1>(
            user,
            DEX_HIPPO,
            HIPPO_CONSTANT_PRODUCT,
            true,
            100,
            0
        );

        assert!(coin::balance<BTC>(user_addr) == 0, 0);
        debug::print(&coin::balance<USDC>(user_addr));
        assert!(coin::balance<USDC>(user_addr) > 0,0 )
    }
}
