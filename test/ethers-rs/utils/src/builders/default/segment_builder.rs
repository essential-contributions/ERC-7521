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
pub struct DefaultIntentSegment {
    call_gas_limit: U256,
    call_data: Bytes,
}

impl DefaultIntentSegment {
    pub fn new(call_gas_limit: U256, call_data: Bytes) -> Self {
        Self {
            call_gas_limit,
            call_data,
        }
    }
}
