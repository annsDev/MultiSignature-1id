// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

/// @title MultiSignature Contract
/// @author 1id
/// @notice Implements the logic for MultiSignature Contract
/// @dev Allows multiple parties to agree on transactions before execution

import "@openzeppelin/contracts/interfaces/IERC20.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";

contract MultiSigWallet {
    /// @notice Expiry can not be a current time
    error InvalidBlockTimeStamp();

    /// @notice Transaction has been already expired
    error TransactionExpired();

    /// @notice Failed to send ether to destination address
    error EthTransferFailed();

    /// @notice Thrown when msg.sender does not have enough ether
    error NotEnoughEther(uint256 ethValue);

    /// @notice Only deployer is allowed to perform this operation
    error OnlyDeployerAllowed();

    /// @notice Owner already exist
    error OwnerAlreadyExists();

    /// @notice Owner does not exist
    error OwnerNotExist();

    /// @notice Owners count is greater than provided number
    error OwnersCountExceeds();

    /// @notice Thrown when provided address is in invalid format
    error InvalidAddress(address providedAddress);

    /// @notice Thrown when transaction is alredy executed
    error TransactionAlreadyExecuted(uint256 transactionId);

    /// @notice Returns the max number of owners that can be added to multisig
    uint128 public max_owner;

    /// @notice Returns the nonce for tracking transaction sequence
    uint256 public nonce;

    /// @notice Returns the current deposit held by the contract
    uint256 public deposit;

    /// @notice Returns the daily spending limit for the contract
    uint256 public dailyLimit;

    /// @notice Returns the timestamp of the last daily spending limit reset
    uint256 public lastReset;

    /// @notice Returns the amount spent today within the daily limit
    uint256 public spentToday;

    /// @notice Returns the added array of addresses representing owners
    address[] public owners;

    /// @notice Returns the address of the contract deployer
    address public deployer;

    /// @notice Returns the number of required owner confirmations for actions
    uint public required;

    /// @notice Returns the total count of transactions processed by the contract
    uint public transactionCount;

    /// @member destination 'To' address where tokens/ether will be sent
    /// @member value The amount in wei/tokens
    /// @member data Transaction data payload.
    /// @member executed Transaction execution status in boolean
    /// @member expireTime Expiry time of transaction in block.timestamp
    struct Transaction {
        address destination;
        uint value;
        bytes data;
        bool executed;
        uint256 expireTime;
    }

    /* ========== STORAGE ========== */

    mapping(uint => Transaction) public transactions;
    mapping(address => bool) public isOwner;
    mapping(address => mapping(address => uint256)) public tokenBalances;

    /* ========== EVENTS ========== */

    event Submission(uint indexed transactionId);
    event Execution(uint indexed transactionId);
    event ExecutionSuccessful(
        uint indexed transactionId,
        address to,
        uint256 value
    );
    event ExecutionFailure(uint indexed transactionId);
    event Deposit(address indexed sender, uint value);
    event Deposited(address from, uint256 value, bytes data);
    event OwnerAddition(address indexed newOwner);
    event OwnerRemoval(address indexed removedOwner);
    event RequirementChange(uint newThreshold);
    event OwnersLimitUpdated(uint128 maxOwners);
    event TokenDepositComplete(address tokenAddress, uint tokenAmount);

    /* ========== MODIFIERS ========== */

    /// @notice throws exeception when non-deployer tries to call
    modifier onlyWallet() {
        if (msg.sender != deployer) {
            revert OnlyDeployerAllowed();
        }
        _;
    }

    /// @notice throws exeception when owner already exists
    modifier ownerDoesNotExist(address owner) {
        if (isOwner[owner]) {
            revert OwnerAlreadyExists();
        }
        _;
    }

    /// @notice throws exeception when owner does not exists
    modifier ownerExists(address owner) {
        if (!isOwner[owner]) {
            revert OwnerNotExist();
        }
        _;
    }

    /// @notice throws exeception when transaction already executed
    modifier notExecuted(uint _transactionId) {
        if (transactions[_transactionId].executed) {
            revert TransactionAlreadyExecuted({transactionId: _transactionId});
        }
        _;
    }

    /// @notice throws exeception when address is invalid
    modifier notNull(address _address) {
        if (_address == address(0)) {
            revert InvalidAddress({providedAddress: _address});
        }
        _;
    }

    /// @notice validate certain requirements before executing constructor
    modifier validRequirement(
        uint ownerCount,
        uint128 _maxOwners,
        uint _required
    ) {
        require(
            ownerCount <= _maxOwners &&
                _required <= ownerCount &&
                _required != 0 &&
                ownerCount != 0,
            "Failed at valid requirements check!"
        );
        _;
    }

    /// @notice validate the requirements for managing ownership in a smart contract
    modifier validCheck(uint ownerCount, uint _required) {
        require(
            ownerCount <= max_owner &&
                _required <= ownerCount &&
                _required != 0 &&
                ownerCount != 0,
            "Validation Failed!"
        );
        _;
    }

    /// @notice validate the daily withdraw limit
    modifier checkDailyLimit(uint256 _value) {
        if (block.timestamp >= lastReset + 1 days) {
            spentToday = 0;
            lastReset = block.timestamp;
        }
        require(spentToday + _value <= dailyLimit, "Daily limit reached.");
        _;
    }

    /// @dev Constructor sets initial owners and required number of confirmations
    /// @param _deployer The deployer of the smart contract
    /// @param _maxOwners Number of max owners that can be added to safe
    /// @param _required Number of required confirmations
    /// @param _limit Daily limit in wei/tokens
    /// @param _owners List of initial owners
    constructor(
        address _deployer,
        uint128 _maxOwners,
        uint _required,
        uint256 _limit,
        address[] memory _owners
    ) validRequirement(_owners.length, _maxOwners, _required) {
        deployer = _deployer;
        max_owner = _maxOwners;
        required = _required;
        lastReset = block.timestamp;
        dailyLimit = _limit;
        spentToday = 0;

        for (uint i = 0; i < _owners.length; i++) {
            require(
                !isOwner[_owners[i]] && _owners[i] != address(0),
                "Provided address is either owner or null"
            );
            owners.push(_owners[i]);
            isOwner[_owners[i]] = true;
        }
    }

    /// @notice Allows to deposit ether
    receive() external payable {
        if (msg.value > 0) emit Deposit(msg.sender, msg.value);
    }

    /// @notice Gets called when a transaction is received with data that does not match any other method
    fallback() external payable {
        if (msg.value > 0) {
            emit Deposited(msg.sender, msg.value, msg.data);
        }
    }

    /// @notice Deposit ETH to the contract
    function depositEther() public payable {
        {
            if (msg.value > 0) {
                deposit = msg.value;
                emit Deposit(msg.sender, msg.value);
            } else revert NotEnoughEther({ethValue: msg.value});
        }
    }

    /// @notice Deposit ERC20 tokens to the contract
    /// @param tokenAddress Contract address of ERC20 token
    /// @param amount The ERC20 token amount to deposit
    function depositToken(address tokenAddress, uint256 amount) external {
        // require(
        //     IERC20(tokenAddress).balanceOf(msg.sender) >= amount,
        //     "Insufficient Balance For Tokens Transfer!"
        // );
        require(
            IERC20(tokenAddress).allowance(msg.sender, address(this)) > 0,
            "Insufficient Token Allowance!"
        );
        IERC20(tokenAddress).transferFrom(msg.sender, address(this), amount);

        tokenBalances[msg.sender][tokenAddress] += amount;
        emit TokenDepositComplete({
            tokenAddress: tokenAddress,
            tokenAmount: amount
        });
    }

    /// @notice Get the balance of an ERC20 token held by the contract
    /// @param _tokenAddress Contract address of ERC20 token
    function tokenBalance(
        address _tokenAddress
    ) public view notNull(_tokenAddress) returns (uint256 _tokenBalance) {
        return IERC20(_tokenAddress).balanceOf(address(this));
    }

    /// @notice Get the ETH balance of the contract
    function contractBalance() public view returns (uint256 _balance) {
        return address(this).balance;
    }

    /// @notice Update the daily spending limit
    /// @param newLimit Daily limit in wei/tokens
    function updateDailyLimit(
        uint256 newLimit
    ) public onlyWallet ownerExists(msg.sender) {
        spentToday = 0;
        dailyLimit = newLimit;

        lastReset = block.timestamp;
    }

    /// @notice Allows to update the limit of max number of owners
    /// @param _maxNumberOfOwners Max number of owners
    function updateMaxOwnerLimit(uint128 _maxNumberOfOwners) public onlyWallet {
        if (_maxNumberOfOwners >= owners.length) {
            max_owner = _maxNumberOfOwners;
            emit OwnersLimitUpdated({maxOwners: _maxNumberOfOwners});
        } else revert OwnersCountExceeds();
    }

    /// @notice Allows to add a new owner
    /// @param owner Address of new owner
    function addOwner(
        address owner
    ) public onlyWallet notNull(owner) ownerDoesNotExist(owner) {
        require(
            owners.length <= max_owner,
            "Maximum limit reached for owners!"
        );
        isOwner[owner] = true;
        owners.push(owner);
        emit OwnerAddition({newOwner: owner});
    }

    /// @notice Allows to remove an owner
    /// @param owner Address of owner
    function removeOwner(address owner) public onlyWallet ownerExists(owner) {
        require(owners.length > 1, "Cannot remove the last owner");
        isOwner[owner] = false;
        
        for (uint i = 0; i < owners.length; i++) {
            if (owners[i] == owner) {
                owners[i] = owners[owners.length - 1];
                owners.pop();
                break;
            }
        }

    if (required > owners.length) {
        changeRequirement(owners.length);
    }
    
    emit OwnerRemoval({removedOwner: owner});
    }


    /// @notice Allows to replace an owner with a new owner
    /// @param owner Address of owner to be replaced
    /// @param newOwner Address of new owner
    function replaceOwner(
        address owner,
        address newOwner
    ) public onlyWallet ownerExists(owner) ownerDoesNotExist(newOwner) {
        for (uint i = 0; i < owners.length; i++)
            if (owners[i] == owner) {
                owners[i] = newOwner;
                break;
            }
        isOwner[owner] = false;
        isOwner[newOwner] = true;
        emit OwnerRemoval({removedOwner: owner});
        emit OwnerAddition({newOwner: newOwner});
    }

    /// @notice Allows to change the number of required confirmations
    /// @param _required Number of required confirmations
    function changeRequirement(
        uint _required
    ) public onlyWallet validCheck(owners.length, _required) {
        required = _required;
        emit RequirementChange({newThreshold: _required});
    }

    /// @notice Allows an owner to submit a transaction
    /// @param destination Transaction target address
    /// @param value Transaction ether value
    /// @param data Transaction data payload
    /// @return transactionId transaction ID
    function submitTransaction(
        address destination,
        uint value,
        bytes memory data,
        uint256 _expireTime
    ) public ownerExists(msg.sender) returns (uint transactionId) {
        if (_expireTime + block.timestamp <= block.timestamp) {
            revert InvalidBlockTimeStamp();
        }
        transactionId = addTransaction(destination, value, data, _expireTime);
    }

    /// @notice Add a new transaction to the transaction mapping, if transaction does not exist yet
    /// @param destination Transaction target address
    /// @param value Transaction ether value
    /// @param data Transaction data payload
    /// @return transactionId Returns the transaction ID
    function addTransaction(
        address destination,
        uint value,
        bytes memory data,
        uint256 _expireTime
    ) internal notNull(destination) returns (uint transactionId) {
        transactionId = transactionCount;
        transactions[transactionId] = Transaction({
            destination: destination,
            value: value,
            data: data,
            executed: false,
            expireTime: block.timestamp + _expireTime
        });
        transactionCount += 1;
        emit Submission({transactionId: transactionId});
    }

    /// @notice internal_function used to verify the signatures and transfer amount to desired address
    /// @param sigV Signature-V
    /// @param sigR Signature-R
    /// @param sigS Signature-S
    /// @param destination 'To' address where funds will be sent
    /// @param value Amount that need to be transfer in Wei
    /// @param data Additional data in bytes
    /// @return bool Returns true if success else false
    function _verifyAndExecute(
        uint8[] memory sigV,
        bytes32[] memory sigR,
        bytes32[] memory sigS,
        address destination,
        uint256 value,
        bytes memory data
    ) internal checkDailyLimit(value) returns (bool) {
        require(
            sigR.length == required,
            "Signatures should be equal to required threshold!"
        );
        require(
            sigR.length == sigS.length && sigR.length == sigV.length,
            "Length Mismatched!"
        );

        bytes32 txHash = keccak256(
            abi.encodePacked(destination, value, data, nonce)
        );

        for (uint256 i = 0; i < required; i++) {
            address recovered = ECDSA.recover(
                ECDSA.toEthSignedMessageHash(txHash),
                sigV[i],
                sigR[i],
                sigS[i]
            );
            require(
                isOwner[recovered],
                "Address does not match with signature"
            );
        }

        nonce = nonce + 1;
        spentToday += value;

        (bool success, ) = destination.call{value: value}(data);
        if (!success) {
            revert EthTransferFailed();
        }
        return true;
    }

    /// @notice Allows owners to execute a signed transaction
    /// @param transactionId Transaction ID
    /// @param sigV Signature-V
    /// @param sigR Signature-R
    /// @param sigS Signature-S
    function executeTransaction(
        uint256 transactionId,
        uint8[] memory sigV,
        bytes32[] memory sigR,
        bytes32[] memory sigS
    ) public ownerExists(msg.sender) notExecuted(transactionId) {
        Transaction storage txn = transactions[transactionId];
        if (block.timestamp > txn.expireTime) {
            revert TransactionExpired();
        }

        txn.executed = true;

        if (
            _verifyAndExecute(
                sigV,
                sigR,
                sigS,
                txn.destination,
                txn.value,
                txn.data
            )
        ) {
            emit ExecutionSuccessful({
                transactionId: transactionId,
                to: txn.destination,
                value: txn.value
            });
        } else {
            emit ExecutionFailure({transactionId: transactionId});
            txn.executed = false;
        }
    }

    /// @notice Returns total number of transactions after filers are applied
    /// @param pending Include pending transactions
    /// @param executed Include executed transactions
    /// @return count Total number of transactions after filters are applied
    function getTransactionCount(
        bool pending,
        bool executed
    ) public view returns (uint count) {
        for (uint i = 0; i < transactionCount; i++)
            if (
                (pending && !transactions[i].executed) ||
                (executed && transactions[i].executed)
            ) count += 1;
    }

    /// @notice Returns list of owners
    /// @return address of owners
    function getOwners() public view returns (address[] memory) {
        return owners;
    }

    /// @notice Returns list of transaction IDs in defined range
    /// @param from Index start position of transaction array
    /// @param to Index end position of transaction array
    /// @param pending Include pending transactions
    /// @param executed Include executed transactions
    /// @return _transactionIds array of transaction IDs
    function getTransactionIds(
        uint from,
        uint to,
        bool pending,
        bool executed
    ) public view returns (uint[] memory _transactionIds) {
        uint[] memory transactionIdsTemp = new uint[](transactionCount);
        uint count = 0;
        uint i;
        for (i = 0; i < transactionCount; i++)
            if (
                (pending && !transactions[i].executed) ||
                (executed && transactions[i].executed)
            ) {
                transactionIdsTemp[count] = i;
                count += 1;
            }
        _transactionIds = new uint[](to - from);
        for (i = from; i < to; i++)
            _transactionIds[i - from] = transactionIdsTemp[i];
    }
}
