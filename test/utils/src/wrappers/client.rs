use ethers::prelude::*;
use k256::ecdsa::SigningKey;
use std::sync::Arc;

pub struct WrappedClient {
    pub client: Arc<SignerMiddleware<Provider<Http>, Wallet<SigningKey>>>,
}
