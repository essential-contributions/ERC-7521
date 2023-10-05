use crate::abigen::TestWrappedNativeToken;
use ethers::prelude::*;
use k256::ecdsa::SigningKey;
use std::sync::Arc;

pub struct TestWrappedNativeTokenContract {
    pub contract: TestWrappedNativeToken<SignerMiddleware<Provider<Http>, Wallet<SigningKey>>>,
}

impl TestWrappedNativeTokenContract {
    pub async fn deploy(client: Arc<SignerMiddleware<Provider<Http>, Wallet<SigningKey>>>) -> Self {
        Self {
            contract: TestWrappedNativeToken::deploy(client.clone(), ())
                .unwrap()
                .send()
                .await
                .unwrap(),
        }
    }

    pub async fn deposit(&self, value: u128) {
        let tx = self.contract.deposit().value(value);
        tx.send().await.unwrap().await.unwrap().unwrap();
    }

    pub async fn transfer(&self, to: Address, amount: U256) {
        let tx = self.contract.transfer(to, amount);
        tx.send().await.unwrap().await.unwrap().unwrap();
    }
}
