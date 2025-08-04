// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {VestingWalletCommunityUpgradeable} from "./VestingWalletCommunityUpgradeable.sol";

contract VestingWalletCommunityFactory is Ownable {
    address public immutable vestingImplementation;

    // MultiSig upgrade configuration
    uint256 public constant REQUIRED_SIGNATURES = 3;
    uint256 public constant TIMELOCK_DURATION = 48 hours;

    mapping(address => bool) public signers;
    address[] public signersList;
    uint256 public signerCount;

    struct UpgradeProposal {
        address vestingWallet;
        address newImplementation;
        uint256 signatures;
        uint256 proposedAt;
        bool executed;
        mapping(address => bool) hasSigned;
    }

    mapping(bytes32 => UpgradeProposal) public upgradeProposals;
    bytes32[] public proposalIds;

    event VestingWalletCreated(
        address indexed vestingWallet,
        address indexed beneficiary,
        address indexed token,
        uint64 startTimestamp
    );

    event ImplementationUpgraded(
        address indexed vestingWallet,
        address indexed oldImplementation,
        address indexed newImplementation
    );

    event UpgradeProposed(
        bytes32 indexed proposalId,
        address indexed vestingWallet,
        address indexed newImplementation,
        address proposer
    );

    event UpgradeSigned(
        bytes32 indexed proposalId,
        address indexed signer,
        uint256 totalSignatures
    );

    event UpgradeExecuted(
        bytes32 indexed proposalId,
        address indexed vestingWallet,
        address indexed newImplementation
    );

    modifier onlySigner() {
        require(signers[msg.sender], "Not a valid signer");
        _;
    }

    constructor(address[] memory _signers) Ownable(msg.sender) {
        require(
            _signers.length >= REQUIRED_SIGNATURES,
            "Not enough initial signers"
        );

        // Deploy the implementation contract
        vestingImplementation = address(
            new VestingWalletCommunityUpgradeable()
        );

        // Set up initial signers
        for (uint256 i = 0; i < _signers.length; i++) {
            require(_signers[i] != address(0), "Invalid signer address");
            require(!signers[_signers[i]], "Duplicate signer");

            signers[_signers[i]] = true;
            signersList.push(_signers[i]);
        }
        signerCount = _signers.length;
    }

    function createVestingWallet(
        string memory contractURI,
        address beneficiary,
        address tokenAddress,
        uint64 startTimestamp
    ) external returns (address) {
        return
            _createVestingWallet(
                contractURI,
                beneficiary,
                tokenAddress,
                startTimestamp
            );
    }

    /**
     * @dev Propose an upgrade for a specific vesting wallet
     */
    function proposeUpgrade(
        address vestingWallet,
        address newImplementation
    ) external onlySigner returns (bytes32) {
        require(vestingWallet != address(0), "Vesting wallet cannot be zero");
        require(
            newImplementation != address(0),
            "Implementation cannot be zero"
        );

        bytes32 proposalId = keccak256(
            abi.encodePacked(vestingWallet, newImplementation, block.timestamp)
        );

        require(
            upgradeProposals[proposalId].proposedAt == 0,
            "Proposal already exists"
        );

        UpgradeProposal storage proposal = upgradeProposals[proposalId];
        proposal.vestingWallet = vestingWallet;
        proposal.newImplementation = newImplementation;
        proposal.signatures = 1;
        proposal.executed = false;
        proposal.proposedAt = block.timestamp;
        proposal.hasSigned[msg.sender] = true;

        proposalIds.push(proposalId);

        emit UpgradeProposed(
            proposalId,
            vestingWallet,
            newImplementation,
            msg.sender
        );
        emit UpgradeSigned(proposalId, msg.sender, 1);

        return proposalId;
    }

    /**
     * @dev Sign an upgrade proposal
     */
    function signUpgrade(bytes32 proposalId) external onlySigner {
        UpgradeProposal storage proposal = upgradeProposals[proposalId];

        require(proposal.proposedAt != 0, "Proposal does not exist");
        require(!proposal.executed, "Proposal already executed");
        require(!proposal.hasSigned[msg.sender], "Already signed");

        proposal.hasSigned[msg.sender] = true;
        proposal.signatures++;

        emit UpgradeSigned(proposalId, msg.sender, proposal.signatures);
    }

    /**
     * @dev Execute an upgrade proposal after timelock period
     */
    function executeUpgrade(bytes32 proposalId) external {
        UpgradeProposal storage proposal = upgradeProposals[proposalId];

        require(proposal.proposedAt != 0, "Proposal does not exist");
        require(!proposal.executed, "Proposal already executed");
        require(
            proposal.signatures >= REQUIRED_SIGNATURES,
            "Not enough signatures"
        );
        require(
            block.timestamp >= proposal.proposedAt + TIMELOCK_DURATION,
            "Timelock period not passed"
        );

        proposal.executed = true;

        address oldImplementation = vestingImplementation;

        VestingWalletCommunityUpgradeable(payable(proposal.vestingWallet))
            .upgradeToAndCall(proposal.newImplementation, "");

        emit UpgradeExecuted(
            proposalId,
            proposal.vestingWallet,
            proposal.newImplementation
        );
        emit ImplementationUpgraded(
            proposal.vestingWallet,
            oldImplementation,
            proposal.newImplementation
        );
    }

    /**
     * @dev Get upgrade proposal details
     */
    function getUpgradeProposal(
        bytes32 proposalId
    )
        external
        view
        returns (
            address vestingWallet,
            address newImplementation,
            uint256 signatures,
            uint256 proposedAt,
            bool executed,
            bool canExecute
        )
    {
        UpgradeProposal storage proposal = upgradeProposals[proposalId];

        vestingWallet = proposal.vestingWallet;
        newImplementation = proposal.newImplementation;
        signatures = proposal.signatures;
        proposedAt = proposal.proposedAt;
        executed = proposal.executed;
        canExecute =
            !executed &&
            signatures >= REQUIRED_SIGNATURES &&
            block.timestamp >= proposedAt + TIMELOCK_DURATION;
    }

    /**
     * @dev Check if an address has signed a proposal
     */
    function hasSignedProposal(
        bytes32 proposalId,
        address signer
    ) external view returns (bool) {
        return upgradeProposals[proposalId].hasSigned[signer];
    }

    /**
     * @dev Get all proposal IDs
     */
    function getAllProposalIds() external view returns (bytes32[] memory) {
        return proposalIds;
    }

    /**
     * @dev Get all signers
     */
    function getAllSigners() external view returns (address[] memory) {
        return signersList;
    }

    function getImplementation() external view returns (address) {
        return vestingImplementation;
    }

    function _createVestingWallet(
        string memory contractURI,
        address beneficiary,
        address tokenAddress,
        uint64 startTimestamp
    ) internal returns (address) {
        require(beneficiary != address(0), "Beneficiary cannot be zero");
        require(tokenAddress != address(0), "Token address cannot be zero");

        // Encode the initializer function call
        bytes memory initData = abi.encodeWithSelector(
            VestingWalletCommunityUpgradeable.initialize.selector,
            contractURI,
            msg.sender,
            beneficiary,
            tokenAddress,
            startTimestamp
        );

        // Deploy the proxy
        ERC1967Proxy proxy = new ERC1967Proxy(vestingImplementation, initData);

        emit VestingWalletCreated(
            address(proxy),
            beneficiary,
            tokenAddress,
            startTimestamp
        );

        return address(proxy);
    }
}
