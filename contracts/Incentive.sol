// SPDX-License-Identifier: MIT
pragma solidity >=0.4.22 <0.9.0;

import '@pancakeswap/pancake-swap-lib/contracts/math/SafeMath.sol';
import '@pancakeswap/pancake-swap-lib/contracts/token/BEP20/IBEP20.sol';
import './Ownable.sol';
import './FuniToken.sol';

contract Incentive is Owner {

    using SafeMath for uint256;
    // using SafeBEP20 for IBEP20;

    address public claimableAdress; // the only address can claim airdrop token and then distribute to other users

    FuniToken public funiToken; // claimed token address

    uint public startBlock;

    uint public lastRewardBlock; // record last reward block
    
    event Claim(uint indexed lastBlock, uint indexed currentBlock, uint indexed amount, address add);
    event ChangeNumberTokenperBlock(uint indexed oldNumer, uint indexed newNumber);

    constructor(FuniToken _funiToken, address add, uint256 _startBlock) public {
        funiToken = _funiToken;
        claimableAdress = add;
        lastRewardBlock = _startBlock;
        startBlock = _startBlock;
    }

    function claim() external{
        require(msg.sender == claimableAdress, "not allow to claim");
        
        uint claimableAmount = getClaimableReward();

        if(claimableAmount == 0){
            return;
        }
        
        funiToken.mint(msg.sender, claimableAmount);
        emit Claim(lastRewardBlock, block.number, claimableAmount, msg.sender);
        lastRewardBlock = block.number;
    }

    /**
     * @dev Returns the result of (base ** exponent) with SafeMath
     * @param base The base number. Example: 2
     * @param exponent The exponent used to raise the base. Example: 3
     * @return A number representing the given base taken to the power of the given exponent. Example: 2 ** 3 = 8
     */
    function pow(uint base, uint exponent) internal pure returns (uint) {
        if (exponent == 0) {
            return 1;
        } else if (exponent == 1) {
            return base;
        } else if (base == 0 && exponent != 0) {
            return 0;
        } else {
            uint result = base;
            for (uint i = 1; i < exponent; i++) {
                result = result.mul(base);
            }
            return result;
        }
    }

    /**
     * @dev Caculate the reward per block at the period: (keepPercent / 100) ** period * initialRewardPerBlock
     * @param periodIndex The period index. The period index must be between [0, maximumPeriodIndex]
     * @return A number representing the reward token per block at specific period. Result is scaled by 1e18.
     */
    function getRewardPerBlock(uint periodIndex) public view returns (uint) {
        if(periodIndex > funiToken.getMaximumPeriodIndex()){
            return 0;
        }
        else{
            return pow(funiToken.getKeepPercent(), periodIndex).mul(funiToken.getInitialRewardPerBlock()).div(pow(100, periodIndex));
        }
    }

    /**
     * @dev Calculate the block number corresponding to each milestone at the beginning of each period.
     * @param periodIndex The period index. The period index must be between [0, maximumPeriodIndex]
     * @return A number representing the block number of the milestone at the beginning of the period.
     */
    function getBlockNumberOfMilestone(uint periodIndex) public view returns (uint) {
        return funiToken.getBlockPerPeriod().mul(periodIndex).add(startBlock);
    }

    /**
     * @dev Determine the period corresponding to any block number.
     * @param blockNumber The block number. The block number must be >= startBlock
     * @return A number representing period index of the input block number.
     */
    function getPeriodIndexByBlockNumber(uint blockNumber) public view returns (uint) {
        require(blockNumber >= startBlock, 'Incentive: blockNumber must be greater or equal startBlock');
        return blockNumber.sub(startBlock).div(funiToken.getBlockPerPeriod());
    }

    /**
     * @dev Calculate the reward that can be claimed from the last received time to the present time.
     * @return A number representing the reclamable FUNI tokens. Result is scaled by 1e18.
     */
    function getClaimableReward() public view returns (uint) {
        uint maxBlock = getBlockNumberOfMilestone(funiToken.getMaximumPeriodIndex() + 1); 
        uint currentBlock = block.number > maxBlock ? maxBlock: block.number;
        
        require(currentBlock >= startBlock, 'Incentive: currentBlock must be greater or equal startBlock');
        
        uint lastClaimPeriod = getPeriodIndexByBlockNumber(lastRewardBlock);
        uint currentPeriod = getPeriodIndexByBlockNumber(currentBlock);
        
        uint startCalculationBlock = lastRewardBlock;
        uint sum = 0;
        
        for(uint i = lastClaimPeriod ; i  <= currentPeriod ; i++) { 
            uint nextBlock = i < currentPeriod ? getBlockNumberOfMilestone(i+1) : currentBlock;
            uint delta = nextBlock.sub(startCalculationBlock);
            sum = sum.add(delta.mul(getRewardPerBlock(i)));
            startCalculationBlock = nextBlock;
        } 
        return sum.mul(funiToken.getIncentiveWeight()).div(100);
    }
}