// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/v4.8.0/contracts/access/AccessControl.sol";

contract TikTrixEscrow is AccessControl {
    address public owner;
    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");
    
    struct Deposit {
        uint256 amount;
        bool isReturned;
    }
    
    mapping(uint256 => mapping(uint256 => mapping(uint256 => Deposit))) public deposits;
    
    event DepositMade(uint256 baseDate, uint256 gameSeq, uint256 memberSeq, uint256 amount);
    event DepositReturned(uint256 baseDate, uint256 gameSeq, uint256 memberSeq, uint256 amount);
    event BatchDepositsReturned(uint256 baseDate, uint256 gameSeq, uint256 count);
    
    constructor() {
        owner = msg.sender;
        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _setupRole(ADMIN_ROLE, msg.sender);
    }
    
    modifier onlyOwner() {
        require(msg.sender == owner, "Only owner can call this function");
        _;
    }

    function grantAdminRole(address account) public onlyRole(DEFAULT_ADMIN_ROLE) {
        grantRole(ADMIN_ROLE, account);
    }

    function revokeAdminRole(address account) public onlyRole(DEFAULT_ADMIN_ROLE) {
        revokeRole(ADMIN_ROLE, account);
    }
    
    function depositFee(uint256 baseDate, uint256 gameSeq, uint256 memberSeq, uint256 amount) external payable {
        require(amount > 0, "Deposit amount must be greater than 0");
        require(deposits[baseDate][gameSeq][memberSeq].amount == 0, "Deposit already exists");
        
        deposits[baseDate][gameSeq][memberSeq] = Deposit({
            amount: amount,
            isReturned: false
        });
        
        emit DepositMade(baseDate, gameSeq, memberSeq, amount);
    }
    
    function returnDepositFee(uint256 baseDate, uint256 gameSeq, uint256 memberSeq) external onlyRole(ADMIN_ROLE) {
        Deposit storage deposit = deposits[baseDate][gameSeq][memberSeq];
        require(deposit.amount > 0, "No deposit found");
        require(!deposit.isReturned, "Deposit already returned");
        
        uint256 amount = deposit.amount;
        deposit.isReturned = true;
        
        (bool success, ) = payable(msg.sender).call{value: amount}("");
        require(success, "Return transfer failed");
        
        emit DepositReturned(baseDate, gameSeq, memberSeq, amount);
    }
    
    function batchReturnDepositFee(
        uint256 baseDate,
        uint256 gameSeq,
        uint256[] calldata memberSeqs
    ) external onlyRole(ADMIN_ROLE) {
        uint256 totalReturned = 0;
        
        for(uint256 i = 0; i < memberSeqs.length; i++) {
            uint256 memberSeq = memberSeqs[i];
            Deposit storage deposit = deposits[baseDate][gameSeq][memberSeq];
            
            if(deposit.amount > 0 && !deposit.isReturned) {
                deposit.isReturned = true;
                totalReturned += deposit.amount;
                
                emit DepositReturned(baseDate, gameSeq, memberSeq, deposit.amount);
            }
        }
        
        if(totalReturned > 0) {
            (bool success, ) = payable(msg.sender).call{value: totalReturned}("");
            require(success, "Batch return transfer failed");
        }
        
        emit BatchDepositsReturned(baseDate, gameSeq, memberSeqs.length);
    }
    
    function getDepositFee(uint256 baseDate, uint256 gameSeq, uint256 memberSeq) 
        external 
        view 
        returns (uint256 amount, bool isReturned) 
    {
        Deposit memory deposit = deposits[baseDate][gameSeq][memberSeq];
        return (deposit.amount, deposit.isReturned);
    }
}