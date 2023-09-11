use super::{abigen::TestERC20, client::WrappedClient};
use ethers::prelude::*;
use k256::ecdsa::SigningKey;

pub struct TestERC20Contract {
    pub contract: TestERC20<SignerMiddleware<Provider<Http>, Wallet<SigningKey>>>,
}

impl TestERC20Contract {
    pub async fn deploy(wrapped_client: &WrappedClient) -> Self {
        Self {
            contract: TestERC20::deploy(wrapped_client.client.clone(), ())
                .unwrap()
                .send()
                .await
                .unwrap(),
        }
    }

    // self.contract.address()
    // U256::from(1000_000000000000000000_u128)
    pub async fn mint(&self, to: Address, amount: U256) {
        let tx = self.contract.mint(to, amount);
        tx.send().await.unwrap();
    }
}
