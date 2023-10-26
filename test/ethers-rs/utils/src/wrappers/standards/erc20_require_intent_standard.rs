use crate::{abigen::Erc20RequireIntentStandard, wrappers::entry_point::EntryPointContract};
use ethers::prelude::*;
use eyre::Result;
use k256::ecdsa::SigningKey;
use std::sync::Arc;

pub struct Erc20RequireIntentStandardContract {
    pub contract: Erc20RequireIntentStandard<SignerMiddleware<Provider<Http>, Wallet<SigningKey>>>,
    pub standard_id: [u8; 32],
}

impl Erc20RequireIntentStandardContract {
    pub async fn deploy(
        client: Arc<SignerMiddleware<Provider<Http>, Wallet<SigningKey>>>,
        entry_point_contract_instance: &EntryPointContract,
    ) -> Self {
        let contract = Erc20RequireIntentStandard::deploy(
            client.clone(),
            entry_point_contract_instance.contract.address(),
        )
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

    pub async fn standard_id(&self) -> Result<[u8; 32]> {
        let tx = self.contract.standard_id();
        match tx.call().await {
            Ok(t) => Result::Ok(t),
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
