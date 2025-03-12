// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract TokenCrowdfunding is Ownable {
    struct Campaign {
        address creator;
        uint256 goal;
        uint256 deadline;
        uint256 fundsRaised;
        bool isCompleted;
    }

    IERC20 public token;
    uint256 public campaignCount;
    mapping(uint256 => Campaign) public campaigns;
    mapping(uint256 => mapping(address => uint256)) public contributions; // External contributions mapping

    event CampaignCreated(uint256 campaignId, address indexed creator, uint256 goal, uint256 deadline);
    event ContributionMade(uint256 campaignId, address indexed contributor, uint256 amount);
    event FundsClaimed(uint256 campaignId, address indexed creator, uint256 amount);
    event RefundIssued(uint256 campaignId, address indexed contributor, uint256 amount);

    constructor(address _tokenAddress) Ownable(msg.sender) { // FIX: Pass msg.sender to Ownable constructor
        require(_tokenAddress != address(0), "Invalid token address");
        token = IERC20(_tokenAddress);
    }

    function createCampaign(uint256 _goal, uint256 _durationInDays) external {
        require(_goal > 0, "Goal must be greater than zero");
        require(_durationInDays > 0, "Duration must be greater than zero");

        campaignCount++;
        campaigns[campaignCount] = Campaign({
            creator: msg.sender,
            goal: _goal,
            deadline: block.timestamp + (_durationInDays * 1 days),
            fundsRaised: 0,
            isCompleted: false
        });

        emit CampaignCreated(campaignCount, msg.sender, _goal, campaigns[campaignCount].deadline);
    }

    function contribute(uint256 _campaignId, uint256 _amount) external {
        require(_campaignId > 0 && _campaignId <= campaignCount, "Invalid campaign ID");

        Campaign storage campaign = campaigns[_campaignId];
        require(block.timestamp < campaign.deadline, "Campaign has ended");
        require(_amount > 0, "Contribution must be greater than zero");

        bool success = token.transferFrom(msg.sender, address(this), _amount);
        require(success, "Token transfer failed");

        campaign.fundsRaised += _amount;
        contributions[_campaignId][msg.sender] += _amount;

        emit ContributionMade(_campaignId, msg.sender, _amount);
    }

    function claimFunds(uint256 _campaignId) external {
        require(_campaignId > 0 && _campaignId <= campaignCount, "Invalid campaign ID");

        Campaign storage campaign = campaigns[_campaignId];
        require(msg.sender == campaign.creator, "Only the creator can claim funds");
        require(block.timestamp >= campaign.deadline, "Campaign is still active");
        require(campaign.fundsRaised >= campaign.goal, "Funding goal not met");
        require(!campaign.isCompleted, "Funds already claimed");

        campaign.isCompleted = true;
        bool success = token.transfer(campaign.creator, campaign.fundsRaised);
        require(success, "Token transfer failed");

        emit FundsClaimed(_campaignId, campaign.creator, campaign.fundsRaised);
    }

    function refund(uint256 _campaignId) external {
        require(_campaignId > 0 && _campaignId <= campaignCount, "Invalid campaign ID");

        Campaign storage campaign = campaigns[_campaignId];
        require(block.timestamp >= campaign.deadline, "Campaign is still active");
        require(campaign.fundsRaised < campaign.goal, "Funding goal met, no refunds");

        uint256 contribution = contributions[_campaignId][msg.sender];
        require(contribution > 0, "No contribution found");

        contributions[_campaignId][msg.sender] = 0;
        bool success = token.transfer(msg.sender, contribution);
        require(success, "Token transfer failed");

        emit RefundIssued(_campaignId, msg.sender, contribution);
    }

    function getCampaignDetails(uint256 _campaignId)
        external
        view
        returns (address, uint256, uint256, uint256, bool)
    {
        require(_campaignId > 0 && _campaignId <= campaignCount, "Invalid campaign ID");

        Campaign storage campaign = campaigns[_campaignId];
        return (campaign.creator, campaign.goal, campaign.deadline, campaign.fundsRaised, campaign.isCompleted);
    }
}
