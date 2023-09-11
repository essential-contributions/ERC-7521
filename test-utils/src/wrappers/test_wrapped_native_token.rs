use super::{abigen::TestWrappedNativeToken, client::WrappedClient};
use ethers::prelude::*;
use k256::ecdsa::SigningKey;

pub struct TestWrappedNativeTokenContract {
    pub contract: TestWrappedNativeToken<SignerMiddleware<Provider<Http>, Wallet<SigningKey>>>,
}

impl TestWrappedNativeTokenContract {
    pub async fn deploy(wrapped_client: &WrappedClient) -> Self {
        Self {
            contract: TestWrappedNativeToken::deploy(wrapped_client.client.clone(), ())
                .unwrap()
                .send()
                .await
                .unwrap(),
        }
    }

    // 1000 * 10 ^ 18
    pub async fn deposit(&self, value: u128) {
        let tx = self.contract.deposit().value(value);
        tx.send().await.unwrap();
    }

    pub async fn transfer(&self, to: Address, amount: U256) {
        let tx = self.contract.transfer(to, amount);
        tx.send().await.unwrap();
    }
}
