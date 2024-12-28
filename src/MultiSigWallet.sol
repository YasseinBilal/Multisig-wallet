// SPDX-License-Identifier: MIT
pragma solidity =0.8.27;

contract MultiSigWalletWithTimelock {
    struct Transaction {
        address to;
        uint256 value;
        uint256 approvals;
        bool executed;
        uint256 requiredSignatures;
        uint256 executeAfter;
        address[] signers;
    }

    mapping(uint txId => mapping(address signer => bool approved))
        public transactionApprovals;

    Transaction[] public transactions;

    event TransactionCreated(
        uint indexed txId,
        address indexed to,
        uint value,
        uint timestamp
    );
    event TransactionApproved(uint indexed txId, address indexed approver);
    event TransactionExecuted(uint indexed txId);

    function initialize() external {}

    modifier onlySigner(uint _txId) {
        bool isSigner = false;
        address[] memory signers = transactions[_txId].signers;

        for (uint i = 0; i < signers.length; i++) {
            if (signers[i] == msg.sender) {
                isSigner = true;
                break;
            }
        }
        require(isSigner, "Only signers can call this function");
        _;
    }

    modifier onlyUniqueSigners(address[] memory _signers) {
        for (uint i = 0; i < _signers.length; i++) {
            for (uint j = i + 1; j < _signers.length; j++) {
                require(_signers[i] != _signers[j], "Signers must be unique");
            }
        }
        _;
    }

    function submitETHTransaction(
        address _to,
        address[] memory _signers,
        uint _requiredSignatures,
        uint _executeAfter
    ) external payable onlyUniqueSigners(_signers) {
        require(_to != address(0), "Invalid recipient");
        require(_signers.length > 0, "Signers required");
        require(
            _requiredSignatures > 0 && _requiredSignatures <= _signers.length,
            "Invalid number of required signatures"
        );

        uint txId = transactions.length;
        transactions.push(
            Transaction({
                to: _to,
                value: msg.value,
                approvals: 0,
                executed: false,
                requiredSignatures: _requiredSignatures,
                executeAfter: _executeAfter,
                signers: _signers
            })
        );

        emit TransactionCreated(txId, _to, msg.value, block.timestamp);
    }

    function approveTransaction(uint _txId) external onlySigner(_txId) {
        Transaction storage transaction = transactions[_txId];

        require(!transaction.executed, "Transaction already executed");
        require(
            !transactionApprovals[_txId][msg.sender],
            "Transaction already approved by this address"
        );

        transaction.approvals += 1;
        transactionApprovals[_txId][msg.sender] = true;

        emit TransactionApproved(_txId, msg.sender);
    }

    function executeETHTransaction(uint _txId) external onlySigner(_txId) {
        Transaction storage transaction = transactions[_txId];

        require(!transaction.executed, "Transaction already executed");
        require(
            transaction.approvals >= transaction.requiredSignatures,
            "Not enough approvals"
        );
        require(
            block.timestamp >= transaction.executeAfter,
            "Transaction is timelocked"
        );

        transaction.executed = true;
        (bool success, ) = transaction.to.call{value: transaction.value}("");
        require(success, "Transaction failed");

        emit TransactionExecuted(_txId);
    }

    receive() external payable {}
}
