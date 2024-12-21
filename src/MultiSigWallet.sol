// SPDX-License-Identifier: MIT
pragma solidity =0.8.27;

contract MultiSigWalletWithTimelock {
    struct Transaction {
        address to;
        uint256 value;
        uint256 timestamp;
        uint256 approvals;
        bool executed;
        uint256 requiredSignatures;
        uint256 timelockDuration;
    }

    mapping(uint txId => mapping(address signer => bool approved))
        public transactionApprovals;
    mapping(uint txId => mapping(address signer => bool isSigner))
        public transactionSigners;

    Transaction[] public transactions;

    event TransactionCreated(
        uint indexed txId,
        address indexed to,
        uint value,
        uint timestamp
    );
    event TransactionApproved(uint indexed txId, address indexed approver);
    event TransactionExecuted(uint indexed txId);

    modifier onlySigner(uint _txId) {
        require(
            transactionSigners[_txId][msg.sender],
            "Not an authorized signer"
        );
        _;
    }

    function submitTransaction(
        address _to,
        uint _value,
        address[] memory _signers,
        uint _requiredSignatures,
        uint _timelockDuration
    ) external {
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
                value: _value,
                timestamp: block.timestamp,
                approvals: 0,
                executed: false,
                requiredSignatures: _requiredSignatures,
                timelockDuration: _timelockDuration
            })
        );

        for (uint i = 0; i < _signers.length; i++) {
            transactionSigners[txId][_signers[i]] = true;
        }

        emit TransactionCreated(txId, _to, _value, block.timestamp);
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

    function executeTransaction(uint _txId) external onlySigner(_txId) {
        Transaction storage transaction = transactions[_txId];

        require(!transaction.executed, "Transaction already executed");
        require(
            transaction.approvals >= transaction.requiredSignatures,
            "Not enough approvals"
        );
        require(
            block.timestamp >=
                transaction.timestamp + transaction.timelockDuration,
            "Transaction is timelocked"
        );

        transaction.executed = true;
        (bool success, ) = transaction.to.call{value: transaction.value}("");
        require(success, "Transaction failed");

        emit TransactionExecuted(_txId);
    }

    receive() external payable {}
}
