// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

/// @title MultiSignature Factory Contract
/// @author 1id
/// @notice Implements the logic for MultiSignature Factory Contract
/// @dev Allows users to deploy new multisig contract

import "./MultiSigWallet.sol";

contract MultiSigFactory {


    /*
     *  Events
     */
    event ContractCreated(
        address contractAddress,
        address[] owners,
        uint256 threshold,
        uint256 dailyLimit
    );

    event Deployer(address deployer);

    MultiSigWallet[] public MultisigArray;

    function CreateNewMultiSig(
        address _deployer,
        address[] memory _owners,
        uint256 _required,
        uint256 _limit
    ) external {
        MultiSigWallet multisigContract = new MultiSigWallet(
            _deployer,
            _owners,
            _required,
            _limit
        );
        MultisigArray.push(multisigContract);

        emit ContractCreated({
            contractAddress: address(multisigContract),
            owners: _owners,
            threshold: _required,
            dailyLimit: _limit
        });

        emit Deployer({deployer: _deployer});
    }
}
