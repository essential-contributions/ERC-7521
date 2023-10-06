use ethers::{prelude::*, utils::parse_ether};
use utils::{
    builders::asset_based_intent_standard::curve_builder::{
        ConstantCurveParameters, CurveParameters, ExponentialCurveParameters, LinearCurveParameters,
    },
    setup::PROVIDER,
};

mod token_swap {
    use super::*;
    use scenarios::token_swaps::token_swap_scenario;

    #[tokio::test]
    async fn constant_release() {
        // block number to evaluate the curves at
        let block_number: U256 =
            std::cmp::max(1, PROVIDER.get_block_number().await.unwrap().as_u64()).into();

        // constant erc20 release curve parameters
        let release_amount = parse_ether(10).unwrap();
        let release_parameters: CurveParameters =
            CurveParameters::Constant(ConstantCurveParameters::new(I256::from_raw(release_amount)));

        // linear eth require curve parameters
        let m = I256::from_raw(parse_ether(0.01).unwrap());
        let b = I256::from_raw(parse_ether(7).unwrap());
        let max = I256::from(100);
        let require_parameters: CurveParameters =
            CurveParameters::Linear(LinearCurveParameters::new(m, b, max));

        // evaluate requirement at block number
        let require_evaluation: U256 = require_parameters.evaluate(block_number).into_raw();

        // run the scenario
        let balances = token_swap_scenario(
            release_parameters,
            require_parameters,
            block_number,
            release_amount,
            require_evaluation,
        )
        .await;

        // calculate expected balances
        let expected_solver_eth_balance =
            balances.solver.eth.initial.unwrap() + release_amount - require_evaluation + 5;
        let expected_user_eth_balance = balances.user.eth.initial.unwrap() + require_evaluation;
        let expected_user_erc20_balance = balances.user.erc20.initial.unwrap() - release_amount;

        // assert balances
        assert_eq!(
            balances.solver.eth.r#final.unwrap(),
            expected_solver_eth_balance,
            "The solver ended up with incorrect balance"
        );
        assert_eq!(
            balances.user.eth.r#final.unwrap(),
            expected_user_eth_balance,
            "The user ended up with incorrect balance"
        );
        assert_eq!(
            balances.user.erc20.r#final.unwrap(),
            expected_user_erc20_balance,
            "The user released more ERC20 tokens than expected"
        );
    }

    #[tokio::test]
    async fn constant_expectation() {
        // block number to evaluate the curves at
        let block_number: U256 =
            std::cmp::max(1, PROVIDER.get_block_number().await.unwrap().as_u64()).into();

        // linear erc20 release curve parameters
        let m = I256::from_raw(parse_ether(0.000075).unwrap());
        let b = I256::from_raw(parse_ether(7).unwrap());
        let e = I256::from(2);
        let max = I256::from(100);
        let release_parameters: CurveParameters =
            CurveParameters::Exponential(ExponentialCurveParameters::new(m, b, e, max));

        // evaluate release at block number
        let release_evaluation: U256 = release_parameters.evaluate(block_number).into_raw();

        // constant eth require curve parameters
        let require_amount = parse_ether(7).unwrap();
        let require_parameters: CurveParameters =
            CurveParameters::Constant(ConstantCurveParameters::new(I256::from_raw(require_amount)));

        // run the scenario
        let balances = token_swap_scenario(
            release_parameters,
            require_parameters,
            block_number,
            release_evaluation,
            require_amount,
        )
        .await;

        // calculate expected balances
        let expected_solver_eth_balance =
            balances.solver.eth.initial.unwrap() + release_evaluation - require_amount + 5;
        let expected_user_eth_balance = balances.user.eth.initial.unwrap() + require_amount;
        let expected_user_erc20_balance = balances.user.erc20.initial.unwrap() - release_evaluation;

        // assert balances
        assert_eq!(
            balances.solver.eth.r#final.unwrap(),
            expected_solver_eth_balance,
            "The solver ended up with incorrect balance"
        );
        assert_eq!(
            balances.user.eth.r#final.unwrap(),
            expected_user_eth_balance,
            "The user ended up with incorrect balance"
        );
        assert_eq!(
            balances.user.erc20.r#final.unwrap(),
            expected_user_erc20_balance,
            "The user released more ERC20 tokens than expected"
        );
    }
}

mod purchase_nft {
    use super::*;
    use scenarios::purchase_nft::purchase_nft_scenario;

    #[tokio::test]
    async fn purchase_nft() {
        // constant erc20 release curve parameters
        let release_amount = parse_ether(2).unwrap();
        let release_parameters: CurveParameters =
            CurveParameters::Constant(ConstantCurveParameters::new(I256::from_raw(release_amount)));

        // run the scenario
        let (balances, nft_price) = purchase_nft_scenario(release_parameters).await;

        // calculate expected balances
        let amount_to_solver = release_amount - nft_price;
        let expected_solver_eth_balance =
            balances.solver.eth.initial.unwrap() + amount_to_solver + 5;
        let expected_user_erc20_balance = balances.user.erc20.initial.unwrap() - release_amount;
        let expected_user_erc1155_balance = U256::from(1);

        // assert balances
        assert_eq!(
            balances.solver.eth.r#final.unwrap(),
            expected_solver_eth_balance,
            "The solver ended up with incorrect balance"
        );
        assert_eq!(
            balances.user.erc20.r#final.unwrap(),
            expected_user_erc20_balance,
            "The user released more ERC20 tokens than expected"
        );
        assert_eq!(
            balances.user.erc1155.r#final.unwrap(),
            expected_user_erc1155_balance,
            "The user did not get their NFT"
        );
    }
}

mod conditional_purchase_nft {
    use super::*;
    use scenarios::conditional_purchase_nft::conditional_purchase_nft_scenario;

    #[tokio::test]
    async fn conditional_purchase_nft() {
        // constant eth release curve parameters
        let release_amount = parse_ether(2).unwrap();
        let release_parameters: CurveParameters =
            CurveParameters::Constant(ConstantCurveParameters::new(I256::from_raw(release_amount)));

        // constant erc721 require curve parameters
        let require_parameters: CurveParameters =
            CurveParameters::Constant(ConstantCurveParameters::new(I256::from(0)));

        // run the scenario
        let (balances, nft_price) =
            conditional_purchase_nft_scenario(release_parameters, require_parameters).await;

        // calculate expected balances
        let expected_solver_eth_balance = balances.solver.eth.initial.unwrap() + release_amount;
        let expected_user_eth_balance =
            balances.user.eth.initial.unwrap() - release_amount - nft_price;
        let expected_user_erc1155_balance = U256::from(1);

        // assert balances
        assert_eq!(
            balances.solver.eth.r#final.unwrap(),
            expected_solver_eth_balance,
            "The solver ended up with incorrect balance"
        );
        assert_eq!(
            balances.user.eth.r#final.unwrap(),
            expected_user_eth_balance,
            "The user ended up with incorrect balance"
        );
        assert_eq!(
            balances.user.erc1155.r#final.unwrap(),
            expected_user_erc1155_balance,
            "The user did not get their NFT"
        );
    }
}

mod gasless_airdrop {
    use super::*;
    use scenarios::gasless_airdrop::gasless_airdrop_scenario;

    #[tokio::test]
    async fn gasless_airdrop() {
        // erc20 airdrop claim amount
        let claim_amount = parse_ether(100).unwrap();

        // constant erc20 release curve parameters
        let release_amount = parse_ether(2).unwrap();
        let release_parameters: CurveParameters =
            CurveParameters::Constant(ConstantCurveParameters::new(I256::from_raw(release_amount)));

        // payment to solver
        let gas_payment = release_amount;

        // run the scenario
        let balances =
            gasless_airdrop_scenario(release_parameters, claim_amount, gas_payment).await;

        // calculate expected balances
        let expected_solver_eth_balance = balances.solver.eth.initial.unwrap() + gas_payment + 5;
        let expected_user_erc20_balance =
            balances.user.erc20.initial.unwrap() + claim_amount - gas_payment;

        // assert balances
        assert_eq!(
            balances.solver.eth.r#final.unwrap(),
            expected_solver_eth_balance,
            "The solver ended up with incorrect balance"
        );
        assert_eq!(
            balances.user.erc20.r#final.unwrap(),
            expected_user_erc20_balance,
            "The user ended up with incorrect ERC20 balance"
        );
    }
}

mod gasless_aidrop_purchase_nft {
    use super::*;
    use scenarios::gasless_airdrop_purchase_nft::gasless_airdrop_purchase_nft_scenario;

    #[tokio::test]
    async fn gasless_aidrop_purchase_nft() {
        // erc20 airdrop claim amount
        let claim_amount = parse_ether(100).unwrap();

        // constant erc20 release curve parameters
        let release_amount = parse_ether(2).unwrap();
        let release_parameters: CurveParameters =
            CurveParameters::Constant(ConstantCurveParameters::new(I256::from_raw(release_amount)));

        // constant eth require curve parameters
        let require_parameters: CurveParameters =
            CurveParameters::Constant(ConstantCurveParameters::new(I256::from(0)));

        // run the scenario
        let (balances, nft_price) = gasless_airdrop_purchase_nft_scenario(
            release_parameters,
            require_parameters,
            claim_amount,
        )
        .await;

        // calculate expected balances
        let expected_solver_eth_balance =
            balances.solver.eth.initial.unwrap() + release_amount - nft_price + 5;
        let expected_user_erc20_balance =
            balances.user.erc20.initial.unwrap() + claim_amount - release_amount;
        let expected_user_erc1155_balance = U256::from(1);

        // assert balances
        assert_eq!(
            balances.solver.eth.r#final.unwrap(),
            expected_solver_eth_balance,
            "The solver ended up with incorrect balance"
        );
        assert_eq!(
            balances.user.erc20.r#final.unwrap(),
            expected_user_erc20_balance,
            "The user released more ERC20 tokens than expected"
        );
        assert_eq!(
            balances.user.erc1155.r#final.unwrap(),
            expected_user_erc1155_balance,
            "The user did not get their NFT"
        );
    }
}

mod gasless_aidrop_conditional_purchase_nft {
    use super::*;
    use scenarios::gasless_airdrop_conditional_purchase_nft::gasless_airdrop_conditional_purchase_nft_scenario;

    #[tokio::test]
    async fn gasless_aidrop_conditional_purchase_nft() {
        // erc20 airdrop claim amount
        let claim_amount = parse_ether(100).unwrap();

        // constant erc20 release curve parameters
        let release_amount = parse_ether(2).unwrap();
        let release_parameters: CurveParameters =
            CurveParameters::Constant(ConstantCurveParameters::new(I256::from_raw(release_amount)));

        // constant erc721 and eth require curve parameters
        let require_parameters: CurveParameters =
            CurveParameters::Constant(ConstantCurveParameters::new(I256::from(0)));

        // run the scenario
        let (balances, nft_price) = gasless_airdrop_conditional_purchase_nft_scenario(
            release_parameters,
            require_parameters,
            claim_amount,
        )
        .await;

        // calculate expected balances
        let expected_solver_eth_balance =
            balances.solver.eth.initial.unwrap() + release_amount - nft_price + 5;
        let expected_user_erc20_balance =
            balances.user.erc20.initial.unwrap() + claim_amount - release_amount;
        let expected_user_erc1155_balance = U256::from(1);

        // assert balances
        assert_eq!(
            balances.solver.eth.r#final.unwrap(),
            expected_solver_eth_balance,
            "The solver ended up with incorrect balance"
        );
        assert_eq!(
            balances.user.erc20.r#final.unwrap(),
            expected_user_erc20_balance,
            "The user released more ERC20 tokens than expected"
        );
        assert_eq!(
            balances.user.erc1155.r#final.unwrap(),
            expected_user_erc1155_balance,
            "The user did not get their NFT"
        );
    }
}
