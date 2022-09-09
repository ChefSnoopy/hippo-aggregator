
module pontem::router {
    use aptos_framework::coin::{Self, Coin};
    public fun swap_exact_coin_for_coin<X, Y, LP>(
        _pool_addr: address,
        coin_in: Coin<X>,
        _mint_out_amt: u64
    ): Coin<Y> {
        coin::destroy_zero(coin_in);
        coin::zero<Y>()
    }
}