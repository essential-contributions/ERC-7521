use crate::{abigen::EthReleaseIntentStandard, wrappers::entry_point::EntryPointContract};
use ethers::prelude::*;
use k256::ecdsa::SigningKey;
use std::sync::Arc;

pub struct EthReleaseIntentStandardContract {
    pub contract: EthReleaseIntentStandard<SignerMiddleware<Provider<Http>, Wallet<SigningKey>>>,
    pub standard_id: [u8; 32],
}

impl EthReleaseIntentStandardContract {
    pub async fn deploy(
        client: Arc<SignerMiddleware<Provider<Http>, Wallet<SigningKey>>>,
        entry_point_contract_instance: &EntryPointContract,
    ) -> Self {
        let contract = EthReleaseIntentStandard::deploy(client.clone(), ())
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
