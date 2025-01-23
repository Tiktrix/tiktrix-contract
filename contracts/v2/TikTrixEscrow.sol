// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import "@thirdweb-dev/contracts/extension/PermissionsEnumerable.sol";
import "@thirdweb-dev/contracts/extension/Multicall.sol";

contract TikTrixEscrow is PermissionsEnumerable, Multicall {
    address public owner;
    bytes32 public constant FACTORY_ROLE = keccak256("FACTORY_ROLE");
    
    struct Deposit {
        uint256 amount;
        bool isReturned;
        address depositor;
    }
    
    mapping(uint256 => mapping(uint256 => mapping(uint256 => Deposit))) public deposits;
    
    event DepositMade(uint256 baseDate, uint256 gameSeq, uint256 memberSeq, uint256 amount);
    event DepositReturned(uint256 baseDate, uint256 gameSeq, uint256 memberSeq, uint256 amount);
    event BatchDepositsReturned(uint256 baseDate, uint256 gameSeq, uint256 count, uint256 totalAmount);
    
    constructor() {
        owner = msg.sender;
        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _setupRole(FACTORY_ROLE, msg.sender);
    }
    
    modifier onlyOwner() {
        require(msg.sender == owner, "Only owner can call this function");
        _;
    }
    
    function depositFee(uint256 baseDate, uint256 gameSeq, uint256 memberSeq) external payable {
        require(msg.value > 0, "Deposit amount must be greater than 0");
        require(deposits[baseDate][gameSeq][memberSeq].amount == 0, "Deposit already exists");
        
        deposits[baseDate][gameSeq][memberSeq] = Deposit({
            amount: msg.value,
            isReturned: false,
            depositor: msg.sender
        });
        
        emit DepositMade(baseDate, gameSeq, memberSeq, msg.value);
    }
    
    function returnDepositFee(uint256 baseDate, uint256 gameSeq, uint256 memberSeq) external onlyRole(FACTORY_ROLE) {
        Deposit storage deposit = deposits[baseDate][gameSeq][memberSeq];
        require(deposit.amount > 0, "No deposit found");
        require(!deposit.isReturned, "Deposit already returned");
        
        uint256 amount = deposit.amount;
        deposit.isReturned = true;

        address depositor = deposit.depositor;
        require(depositor != address(0), "Invalid depositor address");
        
        (bool success, ) = payable(depositor).call{value: amount}("");
        require(success, "Return transfer failed");
        
        emit DepositReturned(baseDate, gameSeq, memberSeq, amount);
    }
    
    function batchReturnDepositFee(
        uint256 baseDate,
        uint256 gameSeq,
        uint256[] calldata memberSeqs
    ) external onlyRole(FACTORY_ROLE) {
        uint256 totalReturned = 0;
        
        for(uint256 i = 0; i < memberSeqs.length; i++) {
            uint256 memberSeq = memberSeqs[i];
            Deposit storage deposit = deposits[baseDate][gameSeq][memberSeq];
            
            if(deposit.amount > 0 && !deposit.isReturned) {
                uint256 amount = deposit.amount;
                deposit.isReturned = true;

                totalReturned += deposit.amount;

                address depositor = deposit.depositor;
                require(depositor != address(0), "Invalid depositor address");
                
                (bool success, ) = payable(depositor).call{value: amount}("");
                require(success, "Return transfer failed");
                
                emit DepositReturned(baseDate, gameSeq, memberSeq, deposit.amount);
            }
        }
        
        emit BatchDepositsReturned(baseDate, gameSeq, memberSeqs.length, totalReturned);
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

