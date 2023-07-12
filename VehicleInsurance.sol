// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract VehicleInsurance {
    receive() external payable {}
    enum CoverageLevel { Basic, Standard, Comprehensive }
    enum ClaimStatus { Pending, Approved, Rejected }
    
      struct Policy {
        address policyHolder;
        uint policyStartDate;
        uint policyEndDate;
        uint premiumAmount;
        bool isActive;
        bool isApproved;
        string vehicleMake;
        string vehicleModel;
        uint vehicleYear;
        string vehicleRegistration;
        CoverageLevel coverage;
        uint policyNumber;
    }
     struct Claim {
        uint claimDate;
        ClaimStatus status;
        uint amount;
        string description;
        string ipfsHash; 
    }

    address public competentAuthority;
    uint private policyCounter;
     mapping(address => Policy) public policies;
    mapping(address => bool) public pendingApprovals;
    mapping(address => Claim[]) public claims;

    
       event PolicyCreated(
        address indexed policyHolder,
        uint indexed policyStartDate,
        uint indexed policyEndDate,
        string vehicleMake,
        string vehicleModel,
        uint vehicleYear,
        string vehicleRegistration,
        CoverageLevel coverage,
        uint premiumAmount,
        uint policyNumber
    );
    event PolicyRenewed(address indexed policyHolder, uint indexed policyEndDate, uint premiumAmount);
    event PolicyCancelled(address indexed policyHolder);
    event PolicyApproved(address indexed policyHolder);
    event ClaimRegistered(address indexed policyHolder, uint indexed claimDate, string description);
    event ClaimProcessed(address indexed policyHolder, uint indexed claimDate, ClaimStatus status, uint amount);

    modifier onlyPolicyHolder() {
        require(policies[msg.sender].isActive, "You don't have an active policy.");
        _;
    }
    
    modifier onlyValidPolicy() {
        require(policies[msg.sender].policyEndDate >= block.timestamp, "Your policy has expired.");
        _;
    }
    modifier onlyCompetentAuthority() {
        require(msg.sender == competentAuthority, "Only competent authority can access this function.");
        _;
    }
     constructor() {
        competentAuthority = msg.sender;
        policyCounter=0;

    }
    
   

    // Function to calculate the premium based on coverage level
    function calculatePremium(CoverageLevel _coverage) public returns (uint256) {
    uint256 premium;
    
    if (_coverage == CoverageLevel.Basic) {
        premium = 1 ether; // Set the premium amount for basic coverage (0.1 ether)
    } else if (_coverage == CoverageLevel.Standard) {
        premium = 2 ether; // Set the premium amount for standard coverage (0.2 ether)
    } else if (_coverage == CoverageLevel.Comprehensive) {
        premium = 3 ether; // Set the premium amount for comprehensive coverage (0.3 ether)
    }
    
    return premium;
}
     function approvePolicy(address _policyHolder) external onlyCompetentAuthority {
        require(pendingApprovals[_policyHolder], "No pending policy approval.");
        require(policies[_policyHolder].isActive, "Policy does not exist.");
        require(!policies[_policyHolder].isApproved, "Policy has already been approved.");
        
        policies[_policyHolder].isApproved = true;
        pendingApprovals[_policyHolder] = false;
        
        // Generate a random policy number
        uint policyNumber = generatePolicyNumber();
        policies[_policyHolder].policyNumber = policyNumber;
        
        emit PolicyApproved(_policyHolder);
        
        // Emit the PolicyCreated event after policy approval
        Policy storage policy = policies[_policyHolder];
        emit PolicyCreated(
            policy.policyHolder,
            policy.policyStartDate,
            policy.policyEndDate,
            policy.vehicleMake,
            policy.vehicleModel,
            policy.vehicleYear,
            policy.vehicleRegistration,
            policy.coverage,
            policy.premiumAmount,
            policy.policyNumber
        );
    }

    function purchasePolicy(
    string calldata _vehicleMake,
    string calldata _vehicleModel,
    uint _vehicleYear,
    string calldata _vehicleRegistration,
    CoverageLevel _coverage, address payable _to
) public payable {
    uint256 premiumAmount;
    
    if (_coverage == CoverageLevel.Basic) {
        premiumAmount = 1 ether;
    } else if (_coverage == CoverageLevel.Standard) {
        premiumAmount = 2 ether;
    } else if (_coverage == CoverageLevel.Comprehensive) {
        premiumAmount = 3 ether;
    }
    
    require(msg.value == premiumAmount, "Incorrect premium amount.");
    require(!policies[msg.sender].isActive, "You already have an active policy.");

    // Transfer the premium amount to the smart contract
    _to.transfer(msg.value);

    uint policyStartDate = block.timestamp;
    uint policyEndDate = policyStartDate + 365 days; // 1-year policy duration

    policies[msg.sender] = Policy(
        msg.sender,
        policyStartDate,
        policyEndDate,
        premiumAmount,
        true,
        false,
        _vehicleMake,
        _vehicleModel,
        _vehicleYear,
        _vehicleRegistration,
        _coverage,
        0 // Initialize policyNumber as 0 before approval
    );

    // Record the pending policy approval
    pendingApprovals[msg.sender] = true;
}

    function generatePolicyNumber() internal returns (uint) {
    uint randomNumber = uint(keccak256(abi.encodePacked(block.timestamp, block.difficulty, policyCounter)));
    policyCounter++; // Increment the policy counter to ensure uniqueness
    return randomNumber;
}
    function renewPolicy(address payable _to) external payable onlyPolicyHolder {
    Policy storage policy = policies[msg.sender];

    require(policy.policyEndDate < block.timestamp, "Policy has not expired yet.");
    require(msg.value > 0, "No premium amount provided.");

    uint policyEndDate = block.timestamp + 365 days; // Extend policy duration by 1 year
    uint premiumAmount = msg.value;

    policy.policyEndDate = policyEndDate;
    policy.premiumAmount = premiumAmount;

    // Transfer the premium amount to the smart contract
    _to.transfer(premiumAmount);

    emit PolicyRenewed(msg.sender, policyEndDate, premiumAmount);
}
    function registerClaim(string calldata _description, string calldata _ipfsHash) external onlyPolicyHolder onlyValidPolicy {
        require(policies[msg.sender].isActive, "You don't have an active policy.");

        Claim memory newClaim = Claim({
            claimDate: block.timestamp,
            status: ClaimStatus.Pending,
            amount: 0,
            description: _description,
            ipfsHash: _ipfsHash // Store the IPFS hash of the FIR
        });

        claims[msg.sender].push(newClaim);

        emit ClaimRegistered(msg.sender, newClaim.claimDate, _description);
    }
    function processClaim(address _policyHolder, uint _claimIndex, bool _isFIRApproved) external payable onlyCompetentAuthority {
    require(policies[_policyHolder].isActive, "Policy does not exist.");

    Claim storage claim = claims[_policyHolder][_claimIndex];
    require(claim.status == ClaimStatus.Pending, "Claim has already been processed.");

    if (_isFIRApproved) {
        require(msg.value > 0, "Claim amount should be greater than zero.");
        // Transfer the approved claim amount to the policy holder
        payable(_policyHolder).transfer(msg.value);
        claim.status = ClaimStatus.Approved;
    } else {
        claim.status = ClaimStatus.Rejected;
    }

    claim.amount = msg.value;

    emit ClaimProcessed(_policyHolder, claim.claimDate, claim.status, msg.value);
      if (claim.status == ClaimStatus.Approved) {
        pendingApprovals[_policyHolder] = false;
    }
}

function getClaimDetails(uint _claimIndex) external view onlyPolicyHolder returns (
        uint claimDate,
        ClaimStatus status,
        uint amount,
        string memory description
    ) {
        Claim memory claim = claims[msg.sender][_claimIndex];
        
        return (
            claim.claimDate,
            claim.status,
            claim.amount,
            claim.description
        );
    }
    
    function cancelPolicy() external onlyPolicyHolder onlyValidPolicy {
        Policy storage policy = policies[msg.sender];
        
        policy.isActive = false;
        
        emit PolicyCancelled(msg.sender);
    }
    
    function getPolicyDetails() external view onlyPolicyHolder returns (
        address policyHolder,
        uint policyStartDate,
        uint policyEndDate,
        uint premiumAmount,
        bool isActive,
        string memory vehicleMake,
        string memory vehicleModel,
        uint vehicleYear,
        string memory vehicleRegistration,
        CoverageLevel coverage
    ) {
        Policy memory policy = policies[msg.sender];
        
        return (
            policy.policyHolder,
            policy.policyStartDate,
            policy.policyEndDate,
            policy.premiumAmount,
            policy.isActive,
            policy.vehicleMake,
            policy.vehicleModel,
            policy.vehicleYear,
            policy.vehicleRegistration,
            policy.coverage
        );
    }
}
