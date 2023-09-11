use super::{
    abigen::{EntryPoint, IntentSolutionLib, RevertReason, UserIntentLib, ENTRYPOINT_ABI},
    client::WrappedClient,
    libs::IntentSolutionLibContract,
};
use crate::unlinked_contract_factory;
use ethers::prelude::*;
use k256::ecdsa::SigningKey;

pub const ENTRYPOINT_ARTIFACT: &str = include_str!("../../../out/EntryPoint.sol/EntryPoint.json");

pub struct EntryPointContract {
    pub contract: EntryPoint<SignerMiddleware<Provider<Http>, Wallet<SigningKey>>>,
    pub intent_solution_lib: IntentSolutionLibContract,
}

impl EntryPointContract {
    pub async fn deploy(wrapped_client: &WrappedClient) -> Self {
        let intent_solution_lib = IntentSolutionLib::deploy(wrapped_client.client.clone(), ())
            .unwrap()
            .send()
            .await
            .unwrap();

        let user_intent_lib = UserIntentLib::deploy(wrapped_client.client.clone(), ())
            .unwrap()
            .send()
            .await
            .unwrap();

        let revert_reason = RevertReason::deploy(wrapped_client.client.clone(), ())
            .unwrap()
            .send()
            .await
            .unwrap();

        let entry_point_factory = unlinked_contract_factory::create(
            ENTRYPOINT_ARTIFACT,
            [
                (
                    "contracts/interfaces/IntentSolution.sol:IntentSolutionLib",
                    intent_solution_lib.address(),
                ),
                (
                    "contracts/interfaces/UserIntent.sol:UserIntentLib",
                    user_intent_lib.address(),
                ),
                (
                    "contracts/utils/Exec.sol:RevertReason",
                    revert_reason.address(),
                ),
            ],
            ENTRYPOINT_ABI.clone(),
            wrapped_client.client.clone(),
        )
        .unwrap();

        let entry_point_contract_instance = entry_point_factory
            .deploy(())
            .unwrap()
            .send()
            .await
            .unwrap();

        let entry_point_contract = EntryPoint::new(
            entry_point_contract_instance.address(),
            wrapped_client.client.clone(),
        );

        Self {
            contract: entry_point_contract,
            intent_solution_lib: IntentSolutionLibContract {
                contract: intent_solution_lib,
            },
        }
    }
}
