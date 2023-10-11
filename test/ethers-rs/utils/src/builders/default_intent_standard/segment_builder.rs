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
    call_data: Bytes,
}

impl DefaultIntentSegment {
    pub fn new(call_data: Bytes) -> Self {
        Self { call_data }
    }
}
