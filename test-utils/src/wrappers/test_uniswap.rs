use super::{abigen::TestUniswap, client::WrappedClient};
use ethers::prelude::*;
use k256::ecdsa::SigningKey;

pub struct TestUniswapContract {
    pub contract: TestUniswap<SignerMiddleware<Provider<Http>, Wallet<SigningKey>>>,
}

impl TestUniswapContract {
    pub async fn deploy(
        wrapped_client: &WrappedClient,
        wrapped_native_token_address: Address,
    ) -> Self {
        Self {
            contract: TestUniswap::deploy(
                wrapped_client.client.clone(),
                wrapped_native_token_address,
            )
            .unwrap()
            .send()
            .await
            .unwrap(),
        }
    }
}
