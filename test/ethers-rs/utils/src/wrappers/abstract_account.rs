use super::{client::WrappedClient, entry_point::EntryPointContract};
use crate::abigen::AbstractAccount;
use ethers::{prelude::*, types::spoof::State};
use k256::ecdsa::SigningKey;

pub struct AbstractAccountContract {
    pub contract: AbstractAccount<SignerMiddleware<Provider<Http>, Wallet<SigningKey>>>,
}

impl AbstractAccountContract {
    pub async fn deploy(
        wrapped_client: &WrappedClient,
        entry_point_contract_instance: &EntryPointContract,
        user_public_key: Address,
    ) -> Self {
        Self {
            contract: AbstractAccount::deploy(
                wrapped_client.client.clone(),
                (
                    entry_point_contract_instance.contract.address(),
                    user_public_key,
                ),
            )
            .unwrap()
            .send()
            .await
            .unwrap(),
        }
    }

    pub async fn funded_state(&self, amount: U256) -> State {
        let mut state = spoof::State::default();

        state.account(self.contract.address()).balance(amount);
        state.account(self.contract.address()).nonce(U64::zero());

        state
    }
}
