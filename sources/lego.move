module hippo_aggregator::lego {
    use aptos_framework::coin::{Self, Coin};
    use hippo_aggregator::providers::SwapPoolInfo;
    use std::vector;

    public fun swap_x_to_y<X, Y, E>(_pool_type: u64, x_in: Coin<X>): Coin<Y> {
        coin::destroy_zero(x_in);
        coin::zero<Y>()
    }

    // not needed if your swapPoolInfo.x_y_order_fixed = false
    public fun swap_y_to_x<X, Y, E>(_pool_type: u64, y_in: Coin<Y>): Coin<X> {
        coin::destroy_zero(y_in);
        coin::zero<X>()
    }
    public fun quote_x_to_y<X, Y, E>(_pool_type: u64, _x_amt: u64): (u64 /*left_over_x*/, u64 /*output_y*/) {
        (0, 0)
    }

    // not needed if your swapPoolInfo.x_y_order_fixed = false
    public fun quote_y_to_x<X, Y, E>(_pool_type: u64, _y_amt: u64): (u64 /*left_over_y*/, u64 /*output_x*/) {
        (0, 0)
    }

    public fun list_all_pools(): vector<SwapPoolInfo> {
        vector::empty<SwapPoolInfo>()
    }
}
