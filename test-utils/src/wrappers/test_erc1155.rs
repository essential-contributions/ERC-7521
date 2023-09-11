use super::{abigen::TestERC1155, client::WrappedClient};
use ethers::prelude::*;
use k256::ecdsa::SigningKey;

pub struct TestERC1155Contract {
    pub contract: TestERC1155<SignerMiddleware<Provider<Http>, Wallet<SigningKey>>>,
}

impl TestERC1155Contract {
    pub async fn deploy(wrapped_client: &WrappedClient) -> Self {
        Self {
            contract: TestERC1155::deploy(wrapped_client.client.clone(), ())
                .unwrap()
                .send()
                .await
                .unwrap(),
        }
    }
}
