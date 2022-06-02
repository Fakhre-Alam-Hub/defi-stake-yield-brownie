// SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;

import "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";


// 100 ETH 1:1 for every 1 ETH, we give 1 DappToken
// 50 ETH and 50 DAI staked, and we want to give a reward of 1 Dapp / 1 DAI

contract TokenFarm is Ownable{
    // Stake Token 
    // Unstake Token 
    // Issue Token 
    // addAllowedTokens
    // getEth values 

    string public name = "Dapp Token Farm";
    IERC20 public dappToken;

    // mapping token address -> staker address -> amount
    mapping(address => mapping(address => uint256)) public stakingBalance;
    address[] public stakers;

    mapping(address => uint256) public uniqueTokensStaked;
    mapping(address => address) public tokenPriceFeedMapping;
    address[] public allowedTokens;

    constructor(address _dappTokenAddress) public {
        dappToken = IERC20(_dappTokenAddress);
    }

    function addAllowedTokens(address token) public onlyOwner {
        allowedTokens.push(token);
    }

    function stakeTokens(uint256 _amount, address token) public {
        // what tokens they can stake
        // how much can they stake
        require(_amount > 0, "amount cannot be 0");
        require(tokenIsAllowed(token), "Token currently isn't allowed");
        IERC20(token).transferFrom(msg.sender, address(this), _amount);
        updateUniqueTokensStaked(msg.sender, token);
        stakingBalance[token][msg.sender] = stakingBalance[token][msg.sender] + _amount;
        if (uniqueTokensStaked[msg.sender] == 1) {
            stakers.push(msg.sender);
        }
    }

    function tokenIsAllowed(address token) public view returns (bool) {
        for (
            uint256 allowedTokensIndex = 0;
            allowedTokensIndex < allowedTokens.length;
            allowedTokensIndex++
        ) {
            if (allowedTokens[allowedTokensIndex] == token) {
                return true;
            }
        }
        return false;
    }


    // Issuing Tokens
    function issueTokens() public onlyOwner {
        // Issue tokens to all stakers
        for (
            uint256 stakersIndex = 0;
            stakersIndex < stakers.length;
            stakersIndex++
        ) {
            address recipient = stakers[stakersIndex];
            // send them a token reward based on their total value locked
            dappToken.transfer(recipient, getUserTotalValue(recipient));
        }
    }


    function updateUniqueTokensStaked(address user, address token) internal {
        if (stakingBalance[token][user] <= 0) {
            uniqueTokensStaked[user] = uniqueTokensStaked[user] + 1;
        }
    }

    function getUserTotalValue(address user) public view returns (uint256) {
        uint256 totalValue = 0;
        if (uniqueTokensStaked[user] > 0) {
            for (
                uint256 allowedTokensIndex = 0;
                allowedTokensIndex < allowedTokens.length;
                allowedTokensIndex++
            ) {
                totalValue =
                    totalValue +
                    getUserTokenStakingBalanceEthValue(
                        user,
                        allowedTokens[allowedTokensIndex]
                    );
            }
        }
        return totalValue;
    }


    function getUserTokenStakingBalanceEthValue(address user, address token)
        public
        view
        returns (uint256){
        if (uniqueTokensStaked[user] <= 0) {
            return 0;
        }
        (uint256 price, uint256 decimals) = getTokenEthPrice(token);
        return (stakingBalance[token][user] * price) / (10**uint256(decimals));
    }


    function getTokenEthPrice(address token) public view returns (uint256, uint256) {
        address priceFeedAddress = tokenPriceFeedMapping[token];
        AggregatorV3Interface priceFeed = AggregatorV3Interface(priceFeedAddress);
        (
            uint80 roundID,
            int256 price,
            uint256 startedAt,
            uint256 timeStamp,
            uint80 answeredInRound
        ) = priceFeed.latestRoundData();
        return (uint256(price), uint256(priceFeed.decimals()));
    }


    function setPriceFeedContract(address token, address priceFeed)
        public
        onlyOwner {
        tokenPriceFeedMapping[token] = priceFeed;
    }

    // Unstaking Tokens (Withdraw)
    function unstakeTokens(address token) public {
     // NOTE:
     // This is vulnerable to a reentrancy attack!!!
        // Fetch staking balance
        uint256 balance = stakingBalance[token][msg.sender];
        require(balance > 0, "staking balance cannot be 0");
        IERC20(token).transfer(msg.sender, balance);
        stakingBalance[token][msg.sender] = 0;
        uniqueTokensStaked[msg.sender] = uniqueTokensStaked[msg.sender] - 1;
    }
}