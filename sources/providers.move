module hippo_aggregator::providers {

    use std::string::String;
    use aptos_std::type_info::{TypeInfo, type_of};
    use aptos_std::simple_map::{Self, SimpleMap};
    use std::signer::address_of;

    struct SwapProviderRegistry has key, copy, drop, store {
        // maps contract_address to SwapPoolProviderInfo
        providers: SimpleMap<address, SwapPoolProviderInfo>,
    }

    struct ApprovedProviders has key, store, copy, drop {
        providers: vector<SwapPoolProviderInfo>,
    }

    struct Nothing has key, copy, drop, store {}

    struct SwapPoolProviderInfo has copy, drop, store {
        swap_name: String,
        pools: SimpleMap<SwapPoolInfo, Nothing>,
        contract_address: address,
        admin_approved: bool,
    }

    struct SwapPoolInfo has key, copy, drop, store {
        x_type: TypeInfo,
        y_type: TypeInfo,
        e_type: TypeInfo,
        pool_type: u64,
        x_y_order_fixed: bool,
    }

    public fun create_pool_info<X, Y, E>(pool_type: u64, x_y_order_fixed: bool): SwapPoolInfo {
        SwapPoolInfo {
            x_type: type_of<X>(),
            y_type: type_of<Y>(),
            e_type: type_of<E>(),
            pool_type,
            x_y_order_fixed,
        }
    }

    const E_NOT_AUTHORIZED: u64 = 1;
    const E_POOL_EXISTS: u64 = 1;

    #[cmd]
    public entry fun register_swap_provider(
        sender: &signer,
        name: String,
        contract_address: address,
    ) acquires SwapProviderRegistry {
        let registry = borrow_global_mut<SwapProviderRegistry>(@hippo_aggregator);

        // check owner_proof has same address as contract_address
        let sender_addr = address_of(sender);
        assert!(sender_addr == contract_address, E_NOT_AUTHORIZED);

        let provider = SwapPoolProviderInfo {
            swap_name: name,
            pools: simple_map::create<SwapPoolInfo, Nothing>(),
            contract_address,
            admin_approved: false,
        };

        // add provider to registry
        simple_map::add(&mut registry.providers, contract_address, provider);
    }

    #[cmd]
    public entry fun admin_register_swap_provider(
        admin: &signer,
        name: String,
        contract_address: address,
    ) acquires SwapProviderRegistry {
        let registry = borrow_global_mut<SwapProviderRegistry>(@hippo_aggregator);
        assert!(address_of(admin) == @hippo_aggregator, E_NOT_AUTHORIZED);

        let provider = SwapPoolProviderInfo {
            swap_name: name,
            pools: simple_map::create<SwapPoolInfo, Nothing>(),
            contract_address,
            admin_approved: true,
        };

        // add provider to registry
        simple_map::add(&mut registry.providers, contract_address, provider);
    }

    #[cmd]
    public entry fun admin_approve_provider(
        admin: &signer,
        contract_address: address,
        approved: bool,
    ) acquires SwapProviderRegistry {
        let registry = borrow_global_mut<SwapProviderRegistry>(@hippo_aggregator);
        assert!(address_of(admin) == @hippo_aggregator, E_NOT_AUTHORIZED);

        let provider = simple_map::borrow_mut(&mut registry.providers, &contract_address);
        provider.admin_approved = approved;
    }

    public fun provider_add_pool<X, Y, E>(
        provider: &mut SwapPoolProviderInfo,
        pool_type: u64,
        x_y_order_fixed: bool,
    ) {
        let pool_info = SwapPoolInfo {
            x_type: type_of<X>(),
            y_type: type_of<Y>(),
            e_type: type_of<E>(),
            pool_type,
            x_y_order_fixed,
        };

        let reverse_pool_info = SwapPoolInfo {
            x_type: type_of<Y>(),
            y_type: type_of<X>(),
            e_type: type_of<E>(),
            pool_type,
            x_y_order_fixed,
        };

        assert!(!simple_map::contains_key(&provider.pools, &reverse_pool_info), E_POOL_EXISTS);

        // add pool to provider
        simple_map::add(&mut provider.pools, pool_info, Nothing {});
    }

    public fun provider_remove_pool<X, Y, E>(
        provider: &mut SwapPoolProviderInfo,
        pool_type: u64,
        x_y_order_fixed: bool,
    ) {
        let pool_info = SwapPoolInfo {
            x_type: type_of<X>(),
            y_type: type_of<Y>(),
            e_type: type_of<E>(),
            pool_type,
            x_y_order_fixed,
        };

        // add pool to provider
        simple_map::remove(&mut provider.pools, &pool_info);
    }

    #[cmd]
    public entry fun add_pool_to_provider<X, Y, E>(
        sender: &signer,
        pool_type: u64,
        x_y_order_fixed: bool,
    ) acquires SwapProviderRegistry {
        let registry = borrow_global_mut<SwapProviderRegistry>(@hippo_aggregator);

        // check owner_proof has same address as contract_address
        let sender_addr = address_of(sender);
        let provider = simple_map::borrow_mut(&mut registry.providers, &sender_addr);

        provider_add_pool<X, Y, E>(provider, pool_type, x_y_order_fixed);
    }

    #[cmd]
    public entry fun remove_pool_from_provider<X, Y, E>(
        sender: &signer,
        pool_type: u64,
        x_y_order_fixed: bool,
    ) acquires SwapProviderRegistry {
        let registry = borrow_global_mut<SwapProviderRegistry>(@hippo_aggregator);
        // check owner_proof has same address as contract_address
        let sender_addr = address_of(sender);

        let provider = simple_map::borrow_mut(&mut registry.providers, &sender_addr);

        provider_remove_pool<X, Y, E>(provider, pool_type, x_y_order_fixed);
    }

    #[cmd]
    public entry fun admin_add_pool_to_provider<X, Y, E>(
        admin: &signer,
        provider_addr: address,
        pool_type: u64,
        x_y_order_fixed: bool,
    ) acquires SwapProviderRegistry {
        assert!(address_of(admin) == @hippo_aggregator, E_NOT_AUTHORIZED);
        let registry = borrow_global_mut<SwapProviderRegistry>(@hippo_aggregator);
        let provider = simple_map::borrow_mut(&mut registry.providers, &provider_addr);
        provider_add_pool<X, Y, E>(provider, pool_type, x_y_order_fixed);
    }

    #[cmd]
    public entry fun admin_remove_pool_from_provider<X, Y, E>(
        admin: &signer,
        provider_addr: address,
        pool_type: u64,
        x_y_order_fixed: bool,
    ) acquires SwapProviderRegistry {
        assert!(address_of(admin) == @hippo_aggregator, E_NOT_AUTHORIZED);
        let registry = borrow_global_mut<SwapProviderRegistry>(@hippo_aggregator);
        let provider = simple_map::borrow_mut(&mut registry.providers, &provider_addr);
        provider_remove_pool<X, Y, E>(provider, pool_type, x_y_order_fixed);
    }
}
