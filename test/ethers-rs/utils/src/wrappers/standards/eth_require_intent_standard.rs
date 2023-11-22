use crate::{abigen::EthRequireIntentStandard, wrappers::entry_point::EntryPointContract};
use ethers::prelude::*;
use k256::ecdsa::SigningKey;
use std::sync::Arc;

pub struct EthRequireIntentStandardContract {
    pub contract: EthRequireIntentStandard<SignerMiddleware<Provider<Http>, Wallet<SigningKey>>>,
    pub standard_id: [u8; 32],
}

impl EthRequireIntentStandardContract {
    pub async fn deploy(
        client: Arc<SignerMiddleware<Provider<Http>, Wallet<SigningKey>>>,
        entry_point_contract_instance: &EntryPointContract,
    ) -> Self {
        let contract = EthRequireIntentStandard::deploy(client.clone(), ())
            .unwrap()
            .send()
            .await
            .unwrap();

        let standard_id = entry_point_contract_instance
            .register_intent_standard(contract.address())
            .await
            .unwrap();

        Self {
            contract,
            standard_id,
        }
    }
}
