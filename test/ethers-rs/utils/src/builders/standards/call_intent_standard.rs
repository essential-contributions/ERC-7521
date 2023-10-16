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
pub struct CallIntentSegment {
    call_data: Bytes,
}

impl CallIntentSegment {
    pub fn new(call_data: Bytes) -> Self {
        Self { call_data }
    }
}
