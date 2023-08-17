use ethers::{
    prelude::{abigen, SignerMiddleware},
    providers::{Http, Provider},
    signers::{LocalWallet, Signer},
    utils::Anvil,
};
use eyre::Result;
use std::{convert::TryFrom, sync::Arc, time::Duration};

abigen!(Account, "out/AbstractAccount.sol/AbstractAccount.json");
abigen!(EntryPoint, "out/EntryPoint.sol/EntryPoint.json");
abigen!(
    AssetBasedIntentStandard,
    "out/AssetBasedIntentStandard.sol/AssetBasedIntentStandard.json"
);

#[tokio::main]
async fn main() -> Result<()> {
    let anvil = Anvil::new().spawn();

    let wallet: LocalWallet = anvil.keys()[0].clone().into();

    let provider =
        Provider::<Http>::try_from(anvil.endpoint())?.interval(Duration::from_millis(10u64));

    let _client = Arc::new(SignerMiddleware::new(
        provider,
        wallet.with_chain_id(anvil.chain_id()),
    ));

    Ok(())
}
