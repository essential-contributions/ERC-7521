use super::curve_builder::{
    AssetBasedIntentCurve, AssetType, CurveFlags, CurveParameters, EvaluationType,
};
use crate::abigen::entry_point::UserIntent;
use ethers::{
    abi::{AbiDecode, AbiEncode, AbiError},
    prelude::*,
};

#[derive(Debug, Clone)]
pub struct AssetBasedIntentSegment {
    call_gas_limit: U256,
    call_data: Vec<Bytes>,
    asset_releases: Vec<AssetBasedIntentCurve>,
    asset_requirements: Vec<AssetBasedIntentCurve>,
}

impl AbiEncode for AssetBasedIntentSegment {
    fn encode(self) -> Vec<u8> {
        let mut encoded = vec![];
        encoded.extend_from_slice(&self.call_gas_limit.encode());
        encoded.extend_from_slice(&self.call_data.encode());
        for asset_release in &self.asset_releases {
            encoded.extend(asset_release.clone().encode());
        }
        for asset_requirement in &self.asset_requirements {
            encoded.extend(asset_requirement.clone().encode());
        }
        encoded
    }
}

impl AbiDecode for AssetBasedIntentSegment {
    // TODO
    fn decode(bytes: impl AsRef<[u8]>) -> Result<Self, AbiError> {
        Ok(Self {
            call_gas_limit: U256::default(),
            call_data: vec![],
            asset_releases: vec![],
            asset_requirements: vec![],
        })
    }
}

impl AssetBasedIntentSegment {
    pub fn new(call_gas_limit: U256, call_data: Vec<Bytes>) -> Self {
        Self {
            call_gas_limit,
            call_data,
            asset_releases: vec![],
            asset_requirements: vec![],
        }
    }

    pub fn decode(self, intent: UserIntent) -> Vec<Self> {
        intent
            .intent_data
            .into_iter()
            .map(|data| AbiDecode::decode(data).unwrap())
            .collect()
    }

    pub fn release_eth(&mut self, curve_parameters: CurveParameters) -> &mut Self {
        self.add_asset_release_curve(
            Address::default(),
            Bytes::default(),
            AssetType::ERC20,
            curve_parameters,
        )
    }

    pub fn release_erc20(
        &mut self,
        address: Address,
        curve_parameters: CurveParameters,
    ) -> &mut Self {
        self.add_asset_release_curve(
            address,
            Bytes::default(),
            AssetType::ERC20,
            curve_parameters,
        )
    }

    pub fn require_eth(
        &mut self,
        curve_parameters: CurveParameters,
        evaluation_type: EvaluationType,
    ) -> &mut Self {
        self.add_asset_requirement_curve(
            Address::default(),
            Bytes::default(),
            AssetType::ETH,
            curve_parameters,
            evaluation_type,
        )
    }

    fn add_asset_release_curve(
        &mut self,
        asset_contract: Address,
        asset_id: Bytes,
        asset_type: AssetType,
        curve_parameters: CurveParameters,
    ) -> &mut Self {
        let curve = AssetBasedIntentCurve::new(
            asset_id,
            asset_contract,
            CurveFlags::new(
                asset_type,
                curve_parameters.get_curve_type(),
                EvaluationType::ABSOLUTE,
            )
            .encode(),
            curve_parameters.into(),
        );

        self.asset_releases.push(curve);

        self
    }

    fn add_asset_requirement_curve(
        &mut self,
        asset_contract: Address,
        asset_id: Bytes,
        asset_type: AssetType,
        curve_parameters: CurveParameters,
        evaluation_type: EvaluationType,
    ) -> &mut Self {
        let curve = AssetBasedIntentCurve::new(
            asset_id,
            asset_contract,
            CurveFlags::new(
                asset_type,
                curve_parameters.get_curve_type(),
                evaluation_type,
            )
            .encode(),
            curve_parameters.into(),
        );
        self.asset_requirements.push(curve);

        self
    }
}
