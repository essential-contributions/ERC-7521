use ethers::{abi::AbiEncode, prelude::*};

pub struct AssetBasedIntentBuilder {
    standard: [u8; 32],
    sender: Address,
    nonce: U256,
    timestamp: U256,
    verification_gas_limit: U256,
    intent_data: Vec<u8>,
    signature: Bytes,
}

impl AssetBasedIntentBuilder {
    pub fn create(
        standard_address: Address,
        standard_id: Bytes,
        nonce: u128,
        timestamp: u128,
    ) -> Self {
        let mut standard: [u8; 32] = Default::default();
        standard[..20].copy_from_slice(standard_address.as_bytes());

        Self {
            standard,
            sender: Address::from_slice(&standard_id),
            nonce: U256::from(nonce),
            timestamp: U256::from(timestamp),
            verification_gas_limit: U256::from(1000000),
            intent_data: vec![],
            signature: Bytes::from_static(b""),
        }
    }

    pub fn add_segment(&mut self, segment: &AssetBasedIntentSegmentBuilder) -> &mut Self {
        let mut intent_data = self.intent_data.clone();
        let mut encoded = vec![];
        encoded.extend_from_slice(&segment.call_gas_limit.encode());
        encoded.extend_from_slice(&segment.call_data);
        for asset_release in &segment.asset_releases {
            for parameter in &asset_release.parameters {
                encoded.extend_from_slice(&parameter.encode());
            }
        }
        for asset_requirement in &segment.asset_requirements {
            for parameter in &asset_requirement.parameters {
                encoded.extend_from_slice(&parameter.encode());
            }
        }

        intent_data.extend_from_slice(&encoded);
        self.intent_data = intent_data;

        self
    }
}

pub struct AssetBasedIntentSegmentBuilder {
    call_gas_limit: U256,
    call_data: Vec<u8>,
    asset_releases: Vec<AssetBasedIntentCurveBuilder>,
    asset_requirements: Vec<AssetBasedIntentCurveBuilder>,
}

pub struct ConstantCurveParameters {
    b: I256,
}

pub struct LinearCurveParameters {
    m: I256,
    b: I256,
    max: I256,
}

pub struct ExponentialCurveParameters {
    m: I256,
    b: I256,
    e: I256,
    max: I256,
}

pub struct AssetBasedIntentCurveBuilder {
    parameters: Vec<I256>,
}
