#[test_only]
module hippo_aggregator::econia {
    use std::signer::address_of;
    use aptos_std::debug::print;
    use aptos_framework::genesis;
    use aptos_framework::coin;
    use coin_list::devnet_coins;
    use coin_list::devnet_coins::{
        DevnetBTC as BTC,
        DevnetUSDC as USDC
    };
    use econia::registry::{E1, init_registry, set_registered_custodian, get_custodian_capability, destroy_custodian_capability};
    use econia::user::{register_market_account, market_account_info, deposit_collateral};
    use econia::market::{init_econia_capability_store, register_market, place_limit_order_custodian};
    use econia::order_id;
    use hippo_aggregator::aggregatorv6::one_step_route;

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
    #[test_only]
    const BID: bool = false;
    #[test_only]
    const BUY: bool = true;
    #[test_only]
    const HI_64: u64 = 0xffffffffffffffff;
    #[test_only]
    const LEFT: bool = true;
    #[test_only]
    const MAX_BID_DEFAULT: u128 = 0;
    #[test_only]
    const MIN_ASK_DEFAULT: u128 = 0xffffffffffffffffffffffffffffffff;
    #[test_only]
    const NO_CUSTODIAN: u64 = 0;
    #[test_only]
    const RIGHT: bool = false;
    #[test_only]
    const SELL: bool = false;

    #[test_only]
    const SCALE_FACTOR: u64 = 10;
    #[test_only]
    const USER_BASE_COINS_START: u64 = 1000000;
    #[test_only]
    const USER_QUOTE_COINS_START: u64 = 2000000;

    // Below constants for end-to-end market order fill testing
    #[test_only]
    const USER_0_CUSTODIAN_ID: u64 = 0; // No custodian flag
    #[test_only]
    const USER_1_CUSTODIAN_ID: u64 = 1;
    #[test_only]
    const USER_2_CUSTODIAN_ID: u64 = 2;
    #[test_only]
    const USER_3_CUSTODIAN_ID: u64 = 3;
    #[test_only]
    const USER_0_START_BASE: u64 = 1000;
    #[test_only]
    const USER_1_START_BASE: u64 = 2000;
    #[test_only]
    const USER_2_START_BASE: u64 = 3000;
    #[test_only]
    const USER_3_START_BASE: u64 = 4000;
    #[test_only]
    const USER_0_START_QUOTE: u64 = 1500;
    #[test_only]
    const USER_1_START_QUOTE: u64 = 2500;
    #[test_only]
    const USER_2_START_QUOTE: u64 = 3500;
    #[test_only]
    const USER_3_START_QUOTE: u64 = 4500;
    #[test_only]
    const USER_1_ASK_PRICE: u64 = 10;
    #[test_only]
    const USER_2_ASK_PRICE: u64 = 11;
    #[test_only]
    const USER_3_ASK_PRICE: u64 = 12;
    #[test_only]
    const USER_1_ASK_SIZE: u64 = 9;
    #[test_only]
    const USER_2_ASK_SIZE: u64 = 8;
    #[test_only]
    const USER_3_ASK_SIZE: u64 = 7;
    #[test_only]
    const USER_1_BID_SIZE: u64 = 3;
    #[test_only]
    const USER_2_BID_SIZE: u64 = 4;
    #[test_only]
    const USER_3_BID_SIZE: u64 = 5;
    #[test_only]
    const USER_1_BID_PRICE: u64 = 5;
    #[test_only]
    const USER_2_BID_PRICE: u64 = 4;
    #[test_only]
    const USER_3_BID_PRICE: u64 = 3;
    #[test_only]
    const USER_1_SERIAL_ID: u64 = 0;
    #[test_only]
    const USER_2_SERIAL_ID: u64 = 1;
    #[test_only]
    const USER_3_SERIAL_ID: u64 = 2;

    // copy from econia/sources/market.move::init_funded_user
    #[test_only]
    public fun init_funded_user<Coin0, Coin1, E>(
        user: &signer,
        custodian_id: u64,
        base_coins: u64,
        quote_coins: u64
    ) {
        // Set custodian ID as in bounds
        set_registered_custodian(custodian_id);
        // Reguster user to trade on the market
        register_market_account<Coin0, Coin1, E>(user, custodian_id);
        // Get market account info
        let market_account_info =
            market_account_info<Coin0, Coin1, E>(custodian_id);
        // Deposit base coin collateral
        deposit_collateral<Coin0>(address_of(user), market_account_info,
            devnet_coins::mint<Coin0>(base_coins));
        // Deposit quote coin collateral
        deposit_collateral<Coin1>(address_of(user), market_account_info,
            devnet_coins::mint<Coin1>(quote_coins));
    }
    // copy from econia/sources/market.move::init_market_test
    #[test_only]
    public fun init_market_test<Coin0, Coin1, E>(
        side: bool,
        econia: &signer,
        host: &signer,
        user_0: &signer,
        user_1: &signer,
        user_2: &signer,
        user_3: &signer,
    ): (
        u128,
        u128,
        u128
    ) {
        init_registry(econia); // Initialize registry
        // Initialize Econia capability store
        init_econia_capability_store(econia);
        // Register test market with Econia as host
        register_market<Coin0, Coin1, E>(host);
        // Initialize funded users
        init_funded_user<Coin0, Coin1, E>(user_0, USER_0_CUSTODIAN_ID,
            USER_0_START_BASE, USER_0_START_QUOTE);
        init_funded_user<Coin0, Coin1, E>(user_1, USER_1_CUSTODIAN_ID,
            USER_1_START_BASE, USER_1_START_QUOTE);
        init_funded_user<Coin0, Coin1, E>(user_2, USER_2_CUSTODIAN_ID,
            USER_2_START_BASE, USER_2_START_QUOTE);
        init_funded_user<Coin0, Coin1, E>(user_3, USER_3_CUSTODIAN_ID,
            USER_3_START_BASE, USER_3_START_QUOTE);
        // Define user order prices and sizes based on market side
        let user_1_order_price = if (side == ASK)
            USER_1_ASK_PRICE else USER_1_BID_PRICE;
        let user_2_order_price = if (side == ASK)
            USER_2_ASK_PRICE else USER_2_BID_PRICE;
        let user_3_order_price = if (side == ASK)
            USER_3_ASK_PRICE else USER_3_BID_PRICE;
        let user_1_order_size = if (side == ASK)
            USER_1_ASK_SIZE else USER_1_BID_SIZE;
        let user_2_order_size = if (side == ASK)
            USER_2_ASK_SIZE else USER_2_BID_SIZE;
        let user_3_order_size = if (side == ASK)
            USER_3_ASK_SIZE else USER_3_BID_SIZE;
        // Define order ID for each user's upcoming order
        let order_id_1 = order_id::order_id(user_1_order_price,
            USER_1_SERIAL_ID, side);
        let order_id_2 = order_id::order_id(user_2_order_price,
            USER_2_SERIAL_ID, side);
        let order_id_3 = order_id::order_id(user_3_order_price,
            USER_3_SERIAL_ID, side);
        // Get custodian capabilities
        let custodian_capability_1 =
            get_custodian_capability(USER_1_CUSTODIAN_ID);
        let custodian_capability_2 =
            get_custodian_capability(USER_2_CUSTODIAN_ID);
        let custodian_capability_3 =
            get_custodian_capability(USER_3_CUSTODIAN_ID);
        // Place limit orders for given side
        place_limit_order_custodian<Coin0, Coin1, E>(address_of(user_1), address_of(host), side,
            user_1_order_size, user_1_order_price, &custodian_capability_1);
        place_limit_order_custodian<Coin0, Coin1, E>(address_of(user_2), address_of(host), side,
            user_2_order_size, user_2_order_price, &custodian_capability_2);
        place_limit_order_custodian<Coin0, Coin1, E>(address_of(user_3), address_of(host), side,
            user_3_order_size, user_3_order_price, &custodian_capability_3);
        // Destroy custodian capabilities
        destroy_custodian_capability(custodian_capability_1);
        destroy_custodian_capability(custodian_capability_2);
        destroy_custodian_capability(custodian_capability_3);
        (order_id_1, order_id_2, order_id_3) // Return order IDs
    }
    #[test(
        econia_admin = @econia,
        aggregator = @hippo_aggregator,
        coin_list_admin = @coin_list,
        user_0 = @user_0,
        user_1 = @user_1,
        user_2 = @user_2,
        user_3 = @user_3,
        swap_user = @0x02
    )]
    fun test_one_step_econia(
        aggregator: &signer,
        econia_admin: &signer,
        coin_list_admin: &signer,
        user_0: &signer,
        user_1: &signer,
        user_2: &signer,
        user_3: &signer,
        swap_user: &signer
    ) {
        genesis::setup();
        devnet_coins::deploy(coin_list_admin);

        init_market_test<BTC, USDC, E1>(ASK, econia_admin, aggregator, user_0, user_1, user_2, user_3);
        let user_3_fill_size = USER_3_ASK_SIZE - 2;
        let quote_coins_spent = // Calculate quote coins spent
            (USER_1_ASK_SIZE * USER_1_ASK_PRICE) +
                (USER_2_ASK_SIZE * USER_2_ASK_PRICE) +
                (user_3_fill_size * USER_3_ASK_PRICE);
        print(&quote_coins_spent);
        devnet_coins::mint_to_wallet<USDC>(swap_user, quote_coins_spent);
        // Place a swap
        one_step_route<USDC, BTC, E1>(
            swap_user,
            DEX_ECONIA,
            ECONIA_V1,
            false,
            quote_coins_spent,
            0
        );

        print(&coin::balance<USDC>(address_of(swap_user)));
        // Assert coin values
        assert!(coin::balance<USDC>(address_of(swap_user)) == 0, 0);

        print(&coin::balance<BTC>(address_of(swap_user)));
        assert!(coin::balance<BTC>(address_of(swap_user)) > 0, 0);
    }
}
