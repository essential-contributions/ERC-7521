use super::client::WrappedClient;
use crate::abigen::TestERC20;
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

    pub async fn mint(&self, to: Address, amount: U256) {
        let tx = self.contract.mint(to, amount);
        tx.send().await.unwrap();
    }

    pub async fn balance_of(&self, account: Address) -> U256 {
        let tx = self.contract.balance_of(account);
        tx.call().await.unwrap()
    }
}
