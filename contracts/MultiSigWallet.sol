// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

/// @title MultiSignature Contract
/// @author 1id
/// @notice Implements the logic for MultiSignature Contract
/// @dev Allows multiple parties to agree on transactions before execution

import "@openzeppelin/contracts/interfaces/IERC20.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";

contract MultiSigWallet {
    using ECDSA for bytes32;

    /// @notice Expiry can not be a current time
    error InvalidBlockTimeStamp();

    /// @notice Transaction has been already expired
    error TransactionExpired();

    /// @notice Failed to send ether to destination address
    error EthTransferFailed();

    /// @notice Thrown when msg.sender does not have enough ether
    error NotEnoughEther();

    uint public constant MAX_OWNER = 5;
    uint256 public nonce;
    address[] public owners;
    address public deployer;
    uint public required;
    uint public transactionCount;
    uint256 public deposit;

    uint256 public dailyLimit;
    uint256 public lastReset;
    uint256 public spentToday;

    /*
     *  Events
     */
    event Submission(uint indexed transactionId);
    event Execution(uint indexed transactionId);
    event ExecutionSuccessful(uint indexed transactionId);
    event ExecutionFailure(uint indexed transactionId);
    event Deposit(address indexed sender, uint value);
    event Deposited(address from, uint256 value, bytes data);
    event OwnerAddition(address indexed owner);
    event OwnerRemoval(address indexed owner);
    event RequirementChange(uint required);
    event TokenDepositComplete(address tokenAddress, uint amount);


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

    /*
     *  Storage
     */
    mapping(uint => Transaction) public transactions;
    mapping(address => bool) public isOwner;
    mapping(address => mapping(address => uint256)) public tokenBalances;

    /*
     *  Modifiers
     */
    modifier onlyWallet() {
        require(
            msg.sender == deployer,
            "Only deployer is allowed to perform this operation!"
        );
        _;
    }

    modifier ownerDoesNotExist(address owner) {
        require(!isOwner[owner]);
        _;
    }

    modifier ownerExists(address owner) {
        require(
            isOwner[owner],
            "Only owner is allowed to perform this operation!"
        );
        _;
    }

    modifier transactionExists(uint transactionId) {
        require(transactions[transactionId].destination != address(0));
        _;
    }

    modifier notExecuted(uint transactionId) {
        require(!transactions[transactionId].executed);
        _;
    }

    modifier notNull(address _address) {
        require(_address != address(0));
        _;
    }

    modifier validRequirement(uint ownerCount, uint _required) {
        require(
            ownerCount <= MAX_OWNER &&
                _required <= ownerCount &&
                _required != 0 &&
                ownerCount != 0,
            "Failed at valid requirements check!"
        );
        _;
    }

    modifier checkDailyLimit(uint256 _value) {
        if (block.timestamp >= lastReset + 1 days) {
            spentToday = 0; // Reset the spending counter
            lastReset = block.timestamp;
        }
        require(spentToday + _value <= dailyLimit, "Daily limit reached.");
        _;
    }

    /// @dev Allows to deposit ether.
    receive() external payable {
        if (msg.value > 0) emit Deposit(msg.sender, msg.value);
    }

    /// @dev Gets called when a transaction is received with data that does not match any other method
    fallback() external payable {
        if (msg.value > 0) {
            emit Deposited(msg.sender, msg.value, msg.data);
        }
    }

    /// @dev Constructor sets initial owners and required number of confirmations.
    /// @param _deployer The deployer of the smart contract.
    /// @param _owners List of initial owners.
    /// @param _required Number of required confirmations.
    /// @param _limit Daily limit in wei/tokens.
    constructor(
        address _deployer,
        address[] memory _owners,
        uint _required,
        uint256 _limit
    ) validRequirement(_owners.length, _required) {
        deployer = _deployer;
        required = _required;
        lastReset = block.timestamp;
        dailyLimit = _limit;
        spentToday = 0;

        for (uint i = 0; i < _owners.length; i++) {
            require(!isOwner[_owners[i]] && _owners[i] != address(0));
            owners.push(_owners[i]);
            isOwner[_owners[i]] = true;
        }
    }

    /// @dev Deposit ETH to the contract
    function depositEther() public payable {
        {
            if (msg.value > 0) {
                deposit = msg.value;
                emit Deposit(msg.sender, msg.value);
            } else revert NotEnoughEther();
        }
    }

    /// @dev Deposit ERC20 tokens to the contract
    /// @param tokenAddress Contract address of ERC20 token
    /// @param amount The ERC20 token amount to deposit
    function depositToken(address tokenAddress, uint256 amount) external {
        require(
            IERC20(tokenAddress).balanceOf(msg.sender) >= amount,
            "Insufficient Balance For Tokens Transfer!"
        );
        require(
            IERC20(tokenAddress).allowance(msg.sender, address(this)) > 0,
            "Insufficient Token Allowance!"
        );
        IERC20(tokenAddress).transferFrom(msg.sender, address(this), amount);

        tokenBalances[msg.sender][tokenAddress] += amount;
        emit TokenDepositComplete(tokenAddress, amount);
    }

    /// @dev Get the balance of an ERC20 token held by the contract
    /// @param _tokenAddress Contract address of ERC20 token
    function tokenBalance(
        address _tokenAddress
    ) public view returns (uint256 _tokenBalance) {
        return IERC20(_tokenAddress).balanceOf(address(this));
    }

    /// @dev Get the ETH balance of the contract
    function contractBalance() public view returns (uint256 _balance) {
        return address(this).balance;
    }

    /// @dev Update the daily spending limit
    /// @param newLimit Daily limit in wei/tokens
    function updateDailyLimit(
        uint256 newLimit
    ) public onlyWallet ownerExists(msg.sender) {
        spentToday = 0;
        dailyLimit = newLimit;

        // Update the last reset timestamp
        lastReset = block.timestamp;
    }

    /// @dev Allows to add a new owner. Transaction has to be sent by wallet.
    /// @param owner Address of new owner.
    function addOwner(
        address owner
    ) public onlyWallet ownerDoesNotExist(owner) notNull(owner) {
        require(
            owners.length <= MAX_OWNER,
            "Maximum amount reached for owners!"
        );
        isOwner[owner] = true;
        owners.push(owner);
        emit OwnerAddition(owner);
    }

    /// @dev Allows to remove an owner. Transaction has to be sent by wallet.
    /// @param owner Address of owner.
    function removeOwner(address owner) public onlyWallet ownerExists(owner) {
        require(owners.length > 1, "Cannot remove the last owner");
        isOwner[owner] = false;
        for (uint i = 0; i < owners.length - 1; i++)
            if (owners[i] == owner) {
                owners[i] = owners[owners.length - 1];
                break;
            }
        [owners.length - 1];
        if (required > owners.length) changeRequirement(owners.length);
        emit OwnerRemoval(owner);
    }

    /// @dev Allows to replace an owner with a new owner. Transaction has to be sent by wallet.
    /// @param owner Address of owner to be replaced.
    /// @param newOwner Address of new owner.
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
        emit OwnerRemoval(owner);
        emit OwnerAddition(newOwner);
    }

    /// @dev Allows to change the number of required confirmations. Transaction has to be sent by wallet.
    /// @param _required Number of required confirmations.
    function changeRequirement(
        uint _required
    ) public onlyWallet validRequirement(owners.length, _required) {
        required = _required;
        emit RequirementChange(_required);
    }

    /// @dev Allows an owner to submit a transaction.
    /// @param destination Transaction target address.
    /// @param value Transaction ether value.
    /// @param data Transaction data payload.
    /// @return transactionId transaction ID.
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

    /// @dev Add a new transaction to the transaction mapping, if transaction does not exist yet.
    /// @param destination Transaction target address.
    /// @param value Transaction ether value.
    /// @param data Transaction data payload.
    /// @return transactionId Returns the transaction ID.
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
            expireTime: _expireTime + block.timestamp
        });
        transactionCount += 1;
        emit Submission({transactionId: transactionId});
    }

    /// @dev internal_function used to verify the signatures and transfer amount to desired address
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

    /// @dev Allows owners to execute a signed transaction.
    /// @param transactionId Transaction ID.
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
            emit ExecutionSuccessful(transactionId);
        } else {
            emit ExecutionFailure(transactionId);
            txn.executed = false;
        }
    }

    /// @dev Returns total number of transactions after filers are applied.
    /// @param pending Include pending transactions.
    /// @param executed Include executed transactions.
    /// @return count Total number of transactions after filters are applied.
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

    /// @dev Returns list of owners.
    /// @return address of owners.
    function getOwners() public view returns (address[] memory) {
        return owners;
    }

    /// @dev Returns list of transaction IDs in defined range.
    /// @param from Index start position of transaction array.
    /// @param to Index end position of transaction array.
    /// @param pending Include pending transactions.
    /// @param executed Include executed transactions.
    /// @return _transactionIds array of transaction IDs.
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
