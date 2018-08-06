pragma solidity 0.4.23;

import "zeppelin-solidity/contracts/math/SafeMath.sol";
import "./BaseMonoretoCrowdsale.sol";


contract MonoretoIco is BaseMonoretoCrowdsale {

    using SafeMath for uint256;

    address public bountyWallet;
    address public teamWallet;

    function MonoretoIco(uint256 _openTime, uint256 _closeTime, uint256 _usdEth,
        uint256 _usdMnr, uint256 _initialRate, uint256 _goal, uint256 _cap, uint256 _tokensTarget,
        address _ownerWallet, MonoretoToken _token) public
        BaseMonoretoCrowdsale(_tokensTarget, _usdEth, _usdMnr)
        CappedCrowdsale(_cap)
        RefundableCrowdsale(_goal)
        FinalizableCrowdsale()
        TimedCrowdsale(_openTime, _closeTime)
        Crowdsale(1, _ownerWallet, _token)
    {
        require(_goal <= _cap);
        rate = _initialRate; // _usdEth.mul(CENT_DECIMALS).div(_usdMnr);

        MonoretoToken castToken = MonoretoToken(token);
        tokenCap = castToken.cap();
    }

    uint256[] public bonusTimes;
    uint256[] public bonusTimesPercents;

    uint256 public tokenCap;

    function setBonusTimes(uint256[] times, uint256[] values) external onlyOwner onlyWhileOpen {
        require(times.length == values.length);

        for (uint256 i = 1; i < times.length; i++) {
            uint256 prevI = i.sub(1);
            require(times[prevI] < times[i]);
        }

        bonusTimes = times;
        bonusTimesPercents = values;

        bonusesSet = true;
    }

    function getBonusTimes() external view returns(uint256[]) {
        return bonusTimes;
    }

    function getBonusTimesPercents() external view returns(uint256[]) {
        return bonusTimesPercents;
    }

    bool private bonusesSet = false;

    function setAdditionalWallets(address _teamWallet, address _bountyWallet) public onlyOwner {
        require(_teamWallet != address(0));
        require(_bountyWallet != address(0));

        teamWallet = _teamWallet;
        bountyWallet = _bountyWallet;
    }

    function _preValidatePurchase(address _beneficiary, uint256 _weiAmount) internal {
        require(bonusesSet);
        super._preValidatePurchase(_beneficiary, _weiAmount);
    }

    uint256 private constant ONE_HUNDRED_PERCENT = 100;

    function _getTokenAmount(uint256 _weiAmount) internal view returns (uint256) {
        return _weiAmount.mul(usdEth).mul(CENT_DECIMALS)
            .mul(computeBonusValueInPercents()).div(ONE_HUNDRED_PERCENT).div(usdMnr);
    }

    /**
     * @dev ICO finalization function.
     * After the end of ICO token must not be minted again
     * Tokens for project, team and bounty will be distributed
     */
    function finalization() internal {
        MonoretoToken castToken = MonoretoToken(token);

        if (goalReached()) {
            require(teamWallet != address(0) && bountyWallet != address(0));

//            uint256 tokenSupply = castToken.cap();

            uint256 projectTokenPercents = 23;
            uint256 teamTokenPercents = 11;
            uint256 bountyTokenPercents = 3;

            castToken.mint(wallet, tokenCap.mul(projectTokenPercents).div(ONE_HUNDRED_PERCENT));
            castToken.mint(teamWallet, tokenCap.mul(teamTokenPercents).div(ONE_HUNDRED_PERCENT));
            castToken.mint(bountyWallet, tokenCap.mul(bountyTokenPercents).div(ONE_HUNDRED_PERCENT));
        }

        castToken.finishMinting();

        super.finalization();
    }

    /**
     * @dev computes the bonus percent corresponding the current time
     * bonuses must be set, of course.
     */
    function computeBonusValueInPercents() private view returns(uint256) {
        for (uint i = 0; i < bonusTimes.length; i++) {
            if (now.sub(openingTime) <= bonusTimes[i]) return bonusTimesPercents[i];
        }

        return ONE_HUNDRED_PERCENT;
    }

}

