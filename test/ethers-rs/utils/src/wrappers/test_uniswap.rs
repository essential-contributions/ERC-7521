use crate::abigen::TestUniswap;
use ethers::prelude::*;
use k256::ecdsa::SigningKey;
use std::sync::Arc;

pub struct TestUniswapContract {
    pub contract: TestUniswap<SignerMiddleware<Provider<Http>, Wallet<SigningKey>>>,
}

impl TestUniswapContract {
    pub async fn deploy(
        client: Arc<SignerMiddleware<Provider<Http>, Wallet<SigningKey>>>,
        wrapped_native_token_address: Address,
    ) -> Self {
        Self {
            contract: TestUniswap::deploy(client.clone(), wrapped_native_token_address)
                .unwrap()
                .send()
                .await
                .unwrap(),
        }
    }
}
