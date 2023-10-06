use crate::abigen::TestERC1155;
use ethers::prelude::*;
use k256::ecdsa::SigningKey;
use std::sync::Arc;

pub struct TestERC1155Contract {
    pub contract: TestERC1155<SignerMiddleware<Provider<Http>, Wallet<SigningKey>>>,
}

impl TestERC1155Contract {
    pub async fn deploy(client: Arc<SignerMiddleware<Provider<Http>, Wallet<SigningKey>>>) -> Self {
        Self {
            contract: TestERC1155::deploy(client.clone(), ())
                .unwrap()
                .send()
                .await
                .unwrap(),
        }
    }

    pub fn buy_nft_calldata(&self, to: Address, amount: U256) -> Bytes {
        let method = self.contract.buy_nft(to, amount);
        method.calldata().unwrap()
    }

    pub async fn balance_of(&self, account: Address, id: U256) -> U256 {
        let tx = self.contract.balance_of(account, id);
        tx.call().await.unwrap()
    }

    pub async fn last_bought_nft(&self) -> U256 {
        let tx = self.contract.last_bought_nft();
        tx.call().await.unwrap()
    }

    pub async fn next_nft_for_sale(&self) -> U256 {
        let tx = self.contract.next_nft_for_sale();
        tx.call().await.unwrap()
    }

    pub async fn nft_cost(&self) -> U256 {
        let tx = self.contract.nft_cost();
        tx.call().await.unwrap()
    }
}
