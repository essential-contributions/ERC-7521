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
pub struct CallIntentSegment {
    pub standard: [u8; 32],
    pub call_data: Bytes,
}

impl CallIntentSegment {
    pub fn new(standard: [u8; 32], call_data: Bytes) -> Self {
        Self {
            standard,
            call_data,
        }
    }
}
