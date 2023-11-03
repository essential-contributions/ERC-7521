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
pub struct SequentialNonceSegment {
    pub standard: [u8; 32],
    pub nonce: U256,
}

impl SequentialNonceSegment {
    pub fn new(standard: [u8; 32], nonce: U256) -> Self {
        Self { standard, nonce }
    }
}
