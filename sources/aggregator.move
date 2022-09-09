module hippo_aggregator::aggregatorv6 {
    use aptos_framework::coin;
    use aptos_framework::account;
    use std::signer;
    use std::option;
    use std::option::Option;
    use hippo_swap::cp_swap;
    use hippo_swap::stable_curve_swap;
    use hippo_swap::piece_swap;
    use econia::market;
    use aptos_std::event::EventHandle;
    use aptos_framework::timestamp;
    use aptos_std::event;
    use aptos_std::type_info::{TypeInfo, type_of};


    const MAX_SIZE: u64 = 9223372036854775808;

    const DEX_HIPPO: u8 = 1;
    const DEX_ECONIA: u8 = 2;
    const DEX_PONTEM: u8 = 3;

    const HIPPO_CONSTANT_PRODUCT:u8 = 1;
    const HIPPO_STABLE_CURVE:u8 = 2;
    const HIPPO_PIECEWISE:u8 = 3;

    const ECONIA_V1: u8 = 1;

    const E_UNKNOWN_POOL_TYPE: u64 = 1;
    const E_OUTPUT_LESS_THAN_MINIMUM: u64 = 2;
    const E_UNKNOWN_DEX: u64 = 3;
    const E_NOT_ADMIN: u64 = 4;

    struct SignerStore has key {
        signer_cap: account::SignerCapability,
    }

    struct EventStore has key {
        swap_step_events: EventHandle<SwapStepEvent>,
    }

    struct SwapStepEvent has drop, store {
        dex_type: u8,
        pool_type: u8,
        // input coin type
        x_type_info: TypeInfo,
        // output coin type
        y_type_info: TypeInfo,
        input_amount: u64,
        output_amount: u64,
        time_stamp: u64
    }

    #[cmd]
    public entry fun initialize(admin: &signer) {
        let admin_addr = signer::address_of(admin);
        assert!(admin_addr == @hippo_aggregator, E_NOT_ADMIN);
        let (_, signer_cap) = account::create_resource_account(admin, b"signerv3");
        move_to(admin, SignerStore { signer_cap });
        move_to(admin, EventStore {
            swap_step_events: account::new_event_handle<SwapStepEvent>(admin)
        });
    }
    fun emit_swap_step_event<Input, Output>(
        dex_type:u8,
        pool_type:u8,
        input_amount:u64,
        output_amount: u64
    ) acquires EventStore {
        let event_store = borrow_global_mut<EventStore>(@hippo_aggregator);
        event::emit_event<SwapStepEvent>(
            &mut event_store.swap_step_events,
            SwapStepEvent {
                dex_type,
                pool_type,
                x_type_info: type_of<coin::Coin<Input>>(),
                y_type_info: type_of<coin::Coin<Output>>(),
                input_amount,
                output_amount,
                time_stamp: timestamp::now_microseconds()
            },
        );
    }
    public fun get_intermediate_output<X, Y, E>(
        dex_type: u8,
        pool_type: u8,
        is_x_to_y: bool,
        x_in: coin::Coin<X>
    ): (Option<coin::Coin<X>>, coin::Coin<Y>) acquires EventStore {
        let coin_in_value = coin::value(&x_in);
        if (dex_type == DEX_HIPPO) {
            if (pool_type == HIPPO_CONSTANT_PRODUCT) {
                if (is_x_to_y) {
                    let (x_out, y_out) = cp_swap::swap_x_to_exact_y_direct<X, Y>(x_in);
                    coin::destroy_zero(x_out);
                    emit_swap_step_event<X, Y>(
                        dex_type,
                        pool_type,
                        coin_in_value,
                        coin::value(&y_out)
                    );
                    (option::none(), y_out)
                }
                else {
                    let (y_out, x_out) = cp_swap::swap_y_to_exact_x_direct<Y, X>(x_in);
                    coin::destroy_zero(x_out);
                    emit_swap_step_event<Y, X>(
                        dex_type,
                        pool_type,
                        coin_in_value,
                        coin::value(&y_out)
                    );
                    (option::none(), y_out)
                }
            }
            else if (pool_type == HIPPO_STABLE_CURVE) {
                if (is_x_to_y) {
                    let (zero, zero2, y_out) = stable_curve_swap::swap_x_to_exact_y_direct<X, Y>(x_in);
                    coin::destroy_zero(zero);
                    coin::destroy_zero(zero2);
                    emit_swap_step_event<X, Y>(
                        dex_type,
                        pool_type,
                        coin_in_value,
                        coin::value(&y_out)
                    );
                    (option::none(), y_out)
                }
                else {
                    let (zero, y_out, zero2) = stable_curve_swap::swap_y_to_exact_x_direct<Y, X>(x_in);
                    coin::destroy_zero(zero);
                    coin::destroy_zero(zero2);
                    emit_swap_step_event<Y, X>(
                        dex_type,
                        pool_type,
                        coin_in_value,
                        coin::value(&y_out)
                    );
                    (option::none(), y_out)
                }
            }
            else if (pool_type == HIPPO_PIECEWISE) {
                if (is_x_to_y) {
                    let y_out = piece_swap::swap_x_to_y_direct<X, Y>(x_in);
                    emit_swap_step_event<X, Y>(
                        dex_type,
                        pool_type,
                        coin_in_value,
                        coin::value(&y_out)
                    );
                    (option::none(), y_out)
                }
                else {
                    let y_out = piece_swap::swap_y_to_x_direct<Y, X>(x_in);
                    emit_swap_step_event<Y, X>(
                        dex_type,
                        pool_type,
                        coin_in_value,
                        coin::value(&y_out)
                    );
                    (option::none(), y_out)
                }
            }
            else {
                abort E_UNKNOWN_POOL_TYPE
            }
        }
        else if (dex_type == DEX_ECONIA) {
            if (pool_type == ECONIA_V1) {
                // deposit into temporary wallet!
                let y_out = coin::zero<Y>();
                if (is_x_to_y) {
                    market::swap<X, Y, E>(false, @hippo_aggregator, &mut x_in, &mut y_out);
                    emit_swap_step_event<X, Y>(
                        dex_type,
                        pool_type,
                        coin_in_value-coin::value(&x_in),
                        coin::value(&y_out)
                    );
                }
                else {
                    market::swap<Y, X, E>(true, @hippo_aggregator, &mut y_out, &mut x_in);
                    emit_swap_step_event<Y, X>(
                        dex_type,
                        pool_type,
                        coin_in_value-coin::value(&x_in),
                        coin::value(&y_out)
                    );
                };
                if (coin::value(&x_in) == 0) {
                    coin::destroy_zero(x_in);
                    (option::none(), y_out)
                }
                else {
                    (option::some(x_in), y_out)
                }
            }
            else {
                abort E_UNKNOWN_POOL_TYPE
            }
        }
        else if (dex_type == DEX_PONTEM) {
            use pontem::router;
            let y_out = router::swap_exact_coin_for_coin<X, Y, E>(@hippo_aggregator, x_in, 0);
            emit_swap_step_event<X, Y>(
                dex_type,
                pool_type,
                coin_in_value,
                coin::value(&y_out)
            );
            (option::none(), y_out)
        }
        else {
            abort E_UNKNOWN_DEX
        }
    }

    fun check_and_deposit_opt<X>(sender: &signer, coin_opt: Option<coin::Coin<X>>) {
        if (option::is_some(&coin_opt)) {
            let coin = option::extract(&mut coin_opt);
            let sender_addr = signer::address_of(sender);
            if (!coin::is_account_registered<X>(sender_addr)) {
                coin::register<X>(sender);
            };
            coin::deposit(sender_addr, coin);
        };
        option::destroy_none(coin_opt)
    }

    fun check_and_deposit<X>(sender: &signer, coin: coin::Coin<X>) {
        let sender_addr = signer::address_of(sender);
        if (!coin::is_account_registered<X>(sender_addr)) {
            coin::register<X>(sender);
        };
        coin::deposit(sender_addr, coin);
    }

    public fun one_step_direct<X, Y, E>(
        dex_type: u8,
        pool_type: u8,
        is_x_to_y: bool,
        x_in: coin::Coin<X>
    ):(Option<coin::Coin<X>>, coin::Coin<Y>) acquires EventStore {
        get_intermediate_output<X, Y, E>(dex_type, pool_type, is_x_to_y, x_in)
    }

    #[cmd]
    public entry fun one_step_route<X, Y, E>(
        sender: &signer,
        first_dex_type: u8,
        first_pool_type: u8,
        first_is_x_to_y: bool, // first trade uses normal order
        x_in: u64,
        y_min_out: u64,
    ) acquires EventStore {
        let coin_in = coin::withdraw<X>(sender, x_in);
        let (coin_remain_opt, coin_out) = one_step_direct<X, Y, E>(first_dex_type, first_pool_type, first_is_x_to_y, coin_in);
        assert!(coin::value(&coin_out) >= y_min_out, E_OUTPUT_LESS_THAN_MINIMUM);
        check_and_deposit_opt(sender, coin_remain_opt);
        check_and_deposit(sender, coin_out);
    }

    public fun two_step_direct<
        X, Y, Z, E1, E2,
    >(
      first_dex_type: u8,
      first_pool_type: u8,
      first_is_x_to_y: bool, // first trade uses normal order
      second_dex_type: u8,
      second_pool_type: u8,
      second_is_x_to_y: bool, // second trade uses normal order
      x_in: coin::Coin<X>
    ):(Option<coin::Coin<X>>, Option<coin::Coin<Y>>, coin::Coin<Z>) acquires EventStore {
        let (coin_x_remain, coin_y) = get_intermediate_output<X, Y, E1>(first_dex_type, first_pool_type, first_is_x_to_y, x_in);
        let (coin_y_remain, coin_z) = get_intermediate_output<Y, Z, E2>(second_dex_type, second_pool_type, second_is_x_to_y, coin_y);
        (coin_x_remain, coin_y_remain, coin_z)
    }

    #[cmd]
    public entry fun two_step_route<
        X, Y, Z, E1, E2,
    >(
        sender: &signer,
        first_dex_type: u8,
        first_pool_type: u8,
        first_is_x_to_y: bool, // first trade uses normal order
        second_dex_type: u8,
        second_pool_type: u8,
        second_is_x_to_y: bool, // second trade uses normal order
        x_in: u64,
        z_min_out: u64,
    ) acquires EventStore {
        let coin_x = coin::withdraw<X>(sender, x_in);
        let (
            coin_x_remain,
            coin_y_remain,
            coin_z
        ) = two_step_direct<X, Y, Z, E1, E2>(
            first_dex_type,
            first_pool_type,
            first_is_x_to_y,
            second_dex_type,
            second_pool_type,
            second_is_x_to_y,
            coin_x
        );
        assert!(coin::value(&coin_z) >= z_min_out, E_OUTPUT_LESS_THAN_MINIMUM);
        check_and_deposit_opt(sender, coin_x_remain);
        check_and_deposit_opt(sender, coin_y_remain);
        check_and_deposit(sender, coin_z);
    }

    public fun three_step_direct<
        X, Y, Z, M, E1, E2, E3
    >(
        first_dex_type: u8,
        first_pool_type: u8,
        first_is_x_to_y: bool, // first trade uses normal order
        second_dex_type: u8,
        second_pool_type: u8,
        second_is_x_to_y: bool, // second trade uses normal order
        third_dex_type: u8,
        third_pool_type: u8,
        third_is_x_to_y: bool, // second trade uses normal order
        x_in: coin::Coin<X>
    ):(Option<coin::Coin<X>>, Option<coin::Coin<Y>>, Option<coin::Coin<Z>>, coin::Coin<M>) acquires EventStore {
        let (coin_x_remain, coin_y) = get_intermediate_output<X, Y, E1>(first_dex_type, first_pool_type, first_is_x_to_y, x_in);
        let (coin_y_remain, coin_z) = get_intermediate_output<Y, Z, E2>(second_dex_type, second_pool_type, second_is_x_to_y, coin_y);
        let (coin_z_remain, coin_m) = get_intermediate_output<Z, M, E3>(third_dex_type, third_pool_type, third_is_x_to_y, coin_z);
        (coin_x_remain, coin_y_remain, coin_z_remain, coin_m)
    }

    #[cmd]
    public entry fun three_step_route<
        X, Y, Z, M, E1, E2, E3
    >(
        sender: &signer,
        first_dex_type: u8,
        first_pool_type: u8,
        first_is_x_to_y: bool, // first trade uses normal order
        second_dex_type: u8,
        second_pool_type: u8,
        second_is_x_to_y: bool, // second trade uses normal order
        third_dex_type: u8,
        third_pool_type: u8,
        third_is_x_to_y: bool, // second trade uses normal order
        x_in: u64,
        m_min_out: u64,
    ) acquires EventStore {
        let coin_x = coin::withdraw<X>(sender, x_in);
        let (
            coin_x_remain,
            coin_y_remain,
            coin_z_remain ,
            coin_m
        ) = three_step_direct<X, Y, Z, M, E1, E2, E3>(
            first_dex_type,
            first_pool_type,
            first_is_x_to_y,
            second_dex_type,
            second_pool_type,
            second_is_x_to_y,
            third_dex_type,
            third_pool_type,
            third_is_x_to_y,
            coin_x
        );
        assert!(coin::value(&coin_m) >= m_min_out, E_OUTPUT_LESS_THAN_MINIMUM);
        check_and_deposit_opt(sender, coin_x_remain);
        check_and_deposit_opt(sender, coin_y_remain);
        check_and_deposit_opt(sender, coin_z_remain);
        check_and_deposit(sender, coin_m);
    }
}
