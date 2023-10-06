use crate::abigen::TestERC20;
use ethers::prelude::*;
use k256::ecdsa::SigningKey;
use std::sync::Arc;

pub struct TestERC20Contract {
    pub contract: TestERC20<SignerMiddleware<Provider<Http>, Wallet<SigningKey>>>,
}

impl TestERC20Contract {
    pub async fn deploy(client: Arc<SignerMiddleware<Provider<Http>, Wallet<SigningKey>>>) -> Self {
        Self {
            contract: TestERC20::deploy(client.clone(), ())
                .unwrap()
                .send()
                .await
                .unwrap(),
        }
    }

    pub async fn mint(&self, to: Address, amount: U256) {
        let tx = self.contract.mint(to, amount);
        tx.send().await.unwrap();
    }

    pub fn mint_calldata(&self, to: Address, amount: U256) -> Bytes {
        let method = self.contract.mint(to, amount);
        method.calldata().unwrap()
    }

    pub async fn balance_of(&self, account: Address) -> U256 {
        let tx = self.contract.balance_of(account);
        tx.call().await.unwrap()
    }
}
