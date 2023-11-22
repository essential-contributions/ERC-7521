use ethers::prelude::*;

#[derive(
    Clone,
    ::ethers::contract::EthAbiType,
    ::ethers::contract::EthAbiCodec,
    Debug,
    PartialEq,
    Eq,
    Hash,
)]
pub struct UserOperationSegment {
    pub standard: [u8; 32],
    pub call_data: Bytes,
    pub call_gas_limit: U256,
}

impl UserOperationSegment {
    pub fn new(standard: [u8; 32], call_data: Bytes, call_gas_limit: U256) -> Self {
        Self {
            standard,
            call_data,
            call_gas_limit,
        }
    }
}
