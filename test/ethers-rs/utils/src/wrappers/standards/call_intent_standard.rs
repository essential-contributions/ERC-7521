use crate::{abigen::CallIntentStandard, wrappers::entry_point::EntryPointContract};
use ethers::prelude::*;
use k256::ecdsa::SigningKey;
use std::sync::Arc;

pub struct CallIntentStandardContract {
    pub contract: CallIntentStandard<SignerMiddleware<Provider<Http>, Wallet<SigningKey>>>,
    pub standard_id: [u8; 32],
}

impl CallIntentStandardContract {
    pub async fn new(
        client: Arc<SignerMiddleware<Provider<Http>, Wallet<SigningKey>>>,
        entry_point_contract_instance: &EntryPointContract,
    ) -> Self {
        let contract = CallIntentStandard::new(
            entry_point_contract_instance.contract.address(),
            client.clone(),
        );
        let standard_id = contract.standard_id().await.unwrap();

        Self {
            contract,
            standard_id,
        }
    }
}
