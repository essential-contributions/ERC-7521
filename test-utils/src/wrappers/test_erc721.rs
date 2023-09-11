use super::{abigen::TestERC721, client::WrappedClient};
use ethers::prelude::*;
use k256::ecdsa::SigningKey;

pub struct TestERC721Contract {
    pub contract: TestERC721<SignerMiddleware<Provider<Http>, Wallet<SigningKey>>>,
}

impl TestERC721Contract {
    pub async fn deploy(wrapped_client: &WrappedClient) -> Self {
        Self {
            contract: TestERC721::deploy(wrapped_client.client.clone(), ())
                .unwrap()
                .send()
                .await
                .unwrap(),
        }
    }
}
