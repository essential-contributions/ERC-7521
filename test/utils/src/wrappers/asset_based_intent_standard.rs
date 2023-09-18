use super::{client::WrappedClient, entry_point::EntryPointContract};
use crate::abigen::{
    AssetBasedIntentCurveLib, AssetBasedIntentStandard, ASSETBASEDINTENTSTANDARD_ABI,
};
use crate::unlinked_contract_factory;
use ethers::prelude::*;
use eyre::Result;
use k256::ecdsa::SigningKey;

pub const ASSETBASEDINTENTSTANDARD_ARTIFACT: &str =
    include_str!("../../../../out/AssetBasedIntentStandard.sol/AssetBasedIntentStandard.json");

pub struct AssetBasedIntentStandardContract {
    pub contract: AssetBasedIntentStandard<SignerMiddleware<Provider<Http>, Wallet<SigningKey>>>,
    pub standard_id: Bytes,
}

impl AssetBasedIntentStandardContract {
    pub async fn deploy(
        wrapped_client: &WrappedClient,
        entry_point_contract_instance: &EntryPointContract,
    ) -> Self {
        let asset_based_intent_curve_lib =
            AssetBasedIntentCurveLib::deploy(wrapped_client.client.clone(), ())
                .unwrap()
                .send()
                .await
                .unwrap();

        let asset_based_intent_standard_factory = unlinked_contract_factory::create(
            ASSETBASEDINTENTSTANDARD_ARTIFACT,
            [
                (
                    "src/interfaces/IntentSolution.sol:IntentSolutionLib",
                    entry_point_contract_instance
                        .intent_solution_lib
                        .contract
                        .address(),
                ),
                (
                    "src/standards/assetbased/AssetBasedIntentCurve.sol:AssetBasedIntentCurveLib",
                    asset_based_intent_curve_lib.address(),
                ),
            ],
            ASSETBASEDINTENTSTANDARD_ABI.clone(),
            wrapped_client.client.clone(),
        )
        .unwrap();

        let asset_based_intent_standard_contract_instance = asset_based_intent_standard_factory
            .deploy(entry_point_contract_instance.contract.address())
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
