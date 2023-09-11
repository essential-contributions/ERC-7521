use super::{abigen::AbstractAccount, client::WrappedClient, entry_point::EntryPointContract};
use ethers::{
    prelude::*,
    utils::{keccak256, secret_key_to_address},
};
use k256::{ecdsa::SigningKey, elliptic_curve::generic_array::GenericArray, SecretKey};

pub struct AbstractAccountContract {
    pub contract: AbstractAccount<SignerMiddleware<Provider<Http>, Wallet<SigningKey>>>,
}

impl AbstractAccountContract {
    pub async fn deploy(
        wrapped_client: &WrappedClient,
        entry_point_contract_instance: &EntryPointContract,
    ) -> Self {
        let key_slice = keccak256("account_private_key".as_bytes());
        let key = SecretKey::from_bytes(&GenericArray::clone_from_slice(&key_slice))
            .expect("did not get private key");

        let account_verifying_key = secret_key_to_address(&SigningKey::from(&key));

        Self {
            contract: AbstractAccount::deploy(
                wrapped_client.client.clone(),
                (
                    entry_point_contract_instance.contract.address(),
                    account_verifying_key,
                ),
            )
            .unwrap()
            .send()
            .await
            .unwrap(),
        }
    }
}
