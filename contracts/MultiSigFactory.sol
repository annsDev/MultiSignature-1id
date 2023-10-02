// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

/// @title MultiSignature Factory Contract
/// @author 1id
/// @notice Implements the logic for MultiSignature Factory Contract
/// @dev Allows users to deploy new multisig contract

import "./MultiSigWallet.sol";

contract MultiSigFactory {


    /* ========== EVENTS ========== */

    event ContractCreated(
        address contractAddress,
        address[] owners,
        uint256 threshold,
        uint256 dailyLimit
    );
    event Deployer(address deployer);

    /// @notice Returns the array of deployed multisig contracts addresses
    MultiSigWallet[] public MultisigArray;

    
    /// @notice Create a new multisig contract
    /// @param _deployer The address of the deployer for the new multisig contract
    /// @param _maxOwners The maximum number of owners that can be added to the multisig
    /// @param _required The number of required owner confirmations for actions in the multisig
    /// @param _limit The daily spending limit for the multisig
    /// @param _owners An array of addresses representing the owners of the multisig
    function CreateNewMultiSig(
        address _deployer,
        uint128 _maxOwners,
        uint256 _required,
        uint256 _limit,
        address[] memory _owners
    ) external {
        MultiSigWallet multisigContract = new MultiSigWallet(
            _deployer,
            _maxOwners,
            _required,
            _limit,
            _owners
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
