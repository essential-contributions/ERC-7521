use ethers::abi::{Abi, Address};
use ethers::prelude::*;
use ethers_solc::{artifacts::ContractBytecode, ConfigurableContractArtifact};
use std::sync::Arc;

fn contract_bytecode(artifact_string: &str) -> std::io::Result<ContractBytecode> {
    let artifact = serde_json::from_str::<ConfigurableContractArtifact>(artifact_string)
        .map_err(|e| std::io::Error::new(std::io::ErrorKind::Other, e))?;
    let contract = artifact.into_contract_bytecode();
    let bytecode: ContractBytecode = contract.into();
    Ok(bytecode)
}

pub fn create<M, I, S>(
    artifact_string: &str,
    libs: I,
    abi: Abi,
    client: Arc<M>,
) -> std::io::Result<ContractFactory<M>>
where
    M: Middleware,
    I: IntoIterator<Item = (S, Address)>,
    S: AsRef<str>,
{
    let mut bytecode_unlinked = contract_bytecode(artifact_string)?;

    if let Some(ref mut bytecode) = bytecode_unlinked.bytecode {
        bytecode.link_all_fully_qualified(libs);
    }
    let bytecode = bytecode_unlinked
        .bytecode
        .ok_or_else(|| std::io::Error::new(std::io::ErrorKind::Other, "missing bytecode"))?;
    debug_assert!(
        bytecode.object.is_bytecode(),
        "bytecode is not fully linked"
    );
    let raw_bytecode = bytecode.object.into_bytes().ok_or_else(|| {
        std::io::Error::new(std::io::ErrorKind::Other, "bytecode is not fully linked")
    })?;
    let factory = ContractFactory::new(abi, raw_bytecode, client);
    Ok(factory)
}
