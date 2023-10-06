use crate::abigen::TestERC721;
use ethers::prelude::*;
use k256::ecdsa::SigningKey;
use std::sync::Arc;

pub struct TestERC721Contract {
    pub contract: TestERC721<SignerMiddleware<Provider<Http>, Wallet<SigningKey>>>,
}

impl TestERC721Contract {
    pub async fn deploy(client: Arc<SignerMiddleware<Provider<Http>, Wallet<SigningKey>>>) -> Self {
        Self {
            contract: TestERC721::deploy(client.clone(), ())
                .unwrap()
                .send()
                .await
                .unwrap(),
        }
    }

    pub fn transfer_from_calldata(&self, from: Address, to: Address, token_id: U256) -> Bytes {
        let method = self.contract.transfer_from(from, to, token_id);
        method.calldata().unwrap()
    }

    pub async fn next_nft_for_sale(&self) -> U256 {
        let tx = self.contract.next_nft_for_sale();
        tx.call().await.unwrap()
    }
}
