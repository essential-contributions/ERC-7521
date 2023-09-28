use super::{client::WrappedClient, entry_point::EntryPointContract};
use crate::abigen::AssetBasedIntentStandard;
use ethers::prelude::*;
use eyre::Result;
use k256::ecdsa::SigningKey;

pub struct AssetBasedIntentStandardContract {
    pub contract: AssetBasedIntentStandard<SignerMiddleware<Provider<Http>, Wallet<SigningKey>>>,
    pub standard_id: Bytes,
}

impl AssetBasedIntentStandardContract {
    pub async fn deploy(
        wrapped_client: &WrappedClient,
        entry_point_contract_instance: &EntryPointContract,
    ) -> Self {
        let asset_based_intent_standard_contract_instance = AssetBasedIntentStandard::deploy(
            wrapped_client.client.clone(),
            entry_point_contract_instance.contract.address(),
        )
        .unwrap()
        .send()
        .await
        .unwrap();

        let standard_address: Address = asset_based_intent_standard_contract_instance.address();

        let standard_id = entry_point_contract_instance
            .register_intent_standard(standard_address)
            .await
            .unwrap();

        Self {
            contract: AssetBasedIntentStandard::new(
                standard_address,
                wrapped_client.client.clone(),
            ),
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
