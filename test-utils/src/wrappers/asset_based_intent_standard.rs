use super::{client::WrappedClient, entry_point::EntryPointContract};
use crate::abigen::{
    AssetBasedIntentCurveLib, AssetBasedIntentStandard, ASSETBASEDINTENTSTANDARD_ABI,
};
use crate::unlinked_contract_factory;
use ethers::prelude::*;
use k256::ecdsa::SigningKey;

pub const ASSETBASEDINTENTSTANDARD_ARTIFACT: &str =
    include_str!("../../../out/AssetBasedIntentStandard.sol/AssetBasedIntentStandard.json");

pub struct AssetBasedIntentStandardContract {
    pub contract: AssetBasedIntentStandard<SignerMiddleware<Provider<Http>, Wallet<SigningKey>>>,
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
                    "contracts/interfaces/IntentSolution.sol:IntentSolutionLib",
                    entry_point_contract_instance
                        .intent_solution_lib
                        .contract
                        .address(),
                ),
                (
                    "contracts/standards/assetbased/AssetBasedIntentCurve.sol:AssetBasedIntentCurveLib",
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

        Self {
            contract: AssetBasedIntentStandard::new(
                asset_based_intent_standard_contract_instance.address(),
                wrapped_client.client.clone(),
            ),
        }
    }
}
