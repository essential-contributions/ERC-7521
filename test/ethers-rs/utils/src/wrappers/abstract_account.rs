use super::entry_point::EntryPointContract;
use crate::{abigen::AbstractAccount, setup::USER_WALLET};
use ethers::{prelude::*, utils::parse_ether};
use k256::ecdsa::SigningKey;
use std::sync::Arc;

pub struct AbstractAccountContract {
    pub contract: AbstractAccount<SignerMiddleware<Provider<Http>, Wallet<SigningKey>>>,
}

impl AbstractAccountContract {
    pub async fn deploy(
        client: Arc<SignerMiddleware<Provider<Http>, Wallet<SigningKey>>>,
        entry_point_contract_instance: &EntryPointContract,
    ) -> Self {
        let contract = AbstractAccount::deploy(
            client.clone(),
            (
                entry_point_contract_instance.contract.address(),
                USER_WALLET.address(),
            ),
        )
        .unwrap()
        .send()
        .await
        .unwrap();

        // fund abstract account
        let tx = TransactionRequest::new()
            .to(contract.address())
            .value(parse_ether(100).unwrap())
            .from(USER_WALLET.address());
        let cloned_client = client.clone();
        cloned_client.send_transaction(tx, None).await.unwrap();

        Self { contract }
    }

    pub fn execute_calldata(&self, target: Address, value: U256, data: Bytes) -> Bytes {
        let method = self.contract.execute(target, value, data);

        method.calldata().unwrap()
    }

    pub fn execute_multi_calldata(
        &self,
        targets: Vec<Address>,
        values: Vec<U256>,
        datas: Vec<Bytes>,
    ) -> Bytes {
        let method = self.contract.execute_multi(targets, values, datas);

        method.calldata().unwrap()
    }
}
