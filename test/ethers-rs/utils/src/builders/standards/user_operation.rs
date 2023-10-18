use ethers::prelude::*;

#[derive(
    Clone,
    ::ethers::contract::EthAbiType,
    ::ethers::contract::EthAbiCodec,
    Default,
    Debug,
    PartialEq,
    Eq,
    Hash,
)]
pub struct UserOperationSegment {
    call_data: Bytes,
    call_gas_limit: U256,
}

impl UserOperationSegment {
    pub fn new(call_data: Bytes, call_gas_limit: U256) -> Self {
        Self {
            call_data,
            call_gas_limit,
        }
    }
}
