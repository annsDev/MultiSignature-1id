// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

/// @title MultiSignature Factory Contract
/// @author Anns Khalid
/// @notice Implements the logic for MultiSignature Factory Contract
/// @dev Allows users to deploy new multisig contract

import "./MultiSigWallet.sol";

contract MultiSigFactory {
    event ContractCreated(
        address contractAddress,
        uint128 maxOwnersLimit,
        uint256 threshold,
        uint256 dailyLimit,
        address[] owners
    );

    event Deployer(address deployer);

    /// @notice Returns the array of deployed multisig contracts addresses
    MultiSigWallet[] public MultisigArray;


    /// @notice Creates a new multisig contract
    /// @param _maxOwnersLimit The maximum number of owners that can be added to the multisig
    /// @param _threshold The number of required owner confirmations for actions in the multisig
    /// @param _dailyLimit The daily spending limit for the multisig
    /// @param _owners An array of addresses representing the owners of the multisig
    function CreateNewMultiSig(
        uint128 _maxOwnersLimit,
        uint256 _threshold,
        uint256 _dailyLimit,
        address[] memory _owners
    ) external {
        MultiSigWallet multisigContract = new MultiSigWallet(
            msg.sender,
            _maxOwnersLimit,
            _threshold,
            _dailyLimit,
            _owners
        );
        MultisigArray.push(multisigContract);

        emit ContractCreated({
            contractAddress: address(multisigContract),
            maxOwnersLimit: _maxOwnersLimit,
            threshold: _threshold,
            dailyLimit: _dailyLimit,
            owners: _owners
        });

        emit Deployer({deployer: msg.sender});
    }
}
