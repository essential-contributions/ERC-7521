use crate::{abigen::CallIntentStandard, wrappers::entry_point::EntryPointContract};
use ethers::prelude::*;
use eyre::Result;
use k256::ecdsa::SigningKey;
use std::sync::Arc;

pub struct CallIntentStandardContract {
    pub contract: CallIntentStandard<SignerMiddleware<Provider<Http>, Wallet<SigningKey>>>,
    pub standard_id: Bytes,
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
        let standard_id: Bytes = contract.standard_id().await.unwrap().into();

        Self {
            contract,
            standard_id,
        }
    }

    pub async fn standard_id(&self) -> Result<Bytes> {
        let tx = self.contract.standard_id();
        match tx.call().await {
            Ok(t) => Result::Ok(Bytes::from(t)),
            Err(e) => {
                if let Some(decoded_error) = e.decode_revert::<String>() {
                    panic!("{}", decoded_error);
                } else {
                    panic!("{}", e);
                }
            }
        }
    }
}
