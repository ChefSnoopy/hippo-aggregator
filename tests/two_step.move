#[test_only]
module hippo_aggregator::two_step {
    use std::signer;
    use aptos_std::debug::print;
    use aptos_framework::coin;
    use aptos_framework::aptos_account;
    use aptos_framework::genesis;

    use hippo_swap::cp_scripts;
    use econia::registry::{E1};
    use coin_list::devnet_coins;
    use coin_list::devnet_coins::{
        DevnetBTC as BTC,
        DevnetUSDC as USDC
    };
    use hippo_aggregator::aggregatorv6::{two_step_route, initialize};
    use hippo_aggregator::econia::init_market_test;

    #[test_only]
    const DEX_HIPPO: u8 = 1;
    #[test_only]
    const DEX_ECONIA: u8 = 2;
    #[test_only]
    const DEX_PONTEM: u8 = 3;
    #[test_only]
    const HIPPO_CONSTANT_PRODUCT:u8 = 1;
    #[test_only]
    const HIPPO_STABLE_CURVE:u8 = 2;
    #[test_only]
    const HIPPO_PIECEWISE:u8 = 3;
    #[test_only]
    const ECONIA_V1: u8 = 1;

    // copy from econia
    #[test_only]
    const ASK: bool = true;

    #[test(
        aggregator = @hippo_aggregator,
        hippo_swap = @hippo_swap,
        econia = @econia,
        coin_list = @coin_list,
        user_0 = @0x2,
        user_1 = @0x3,
        user_2 = @0x4,
        user_3 = @0x5,
        swap_user = @0x6
    )]
    fun test_two_step(
        aggregator: &signer,
        hippo_swap: &signer,
        econia: &signer,
        coin_list: &signer,
        user_0: &signer,
        user_1: &signer,
        user_2: &signer,
        user_3: &signer,
        swap_user: &signer
    ){
        genesis::setup();
        aptos_account::create_account(signer::address_of(aggregator));
        initialize(aggregator);
        if (signer::address_of(hippo_swap) != signer::address_of(aggregator)) {
            aptos_account::create_account(signer::address_of(hippo_swap));
        };
        devnet_coins::deploy(coin_list);
        cp_scripts::mock_deploy_script(hippo_swap);
        init_market_test<BTC, USDC, E1>(ASK, econia, aggregator, user_0, user_1, user_2, user_3);
        let quote_coins_spent:u64 = 238;
        devnet_coins::mint_to_wallet<USDC>(swap_user, quote_coins_spent);
        print(&coin::balance<USDC>(signer::address_of(swap_user)));
        two_step_route<USDC, BTC, USDC, E1, E1>(
            swap_user,
            DEX_ECONIA,
            ECONIA_V1,
            false,
            DEX_HIPPO,
            HIPPO_CONSTANT_PRODUCT,
            true,
            quote_coins_spent,
            0
        );
        print(&coin::balance<USDC>(signer::address_of(swap_user)));
    }
}
