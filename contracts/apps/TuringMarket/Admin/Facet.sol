// SPDX-License-Identifier: MIT
pragma solidity >=0.8.20;

import {Facet} from "../../../Facet.sol";
import {AdminBase} from "./Base.sol";
import {IAdminFacet} from "./IFacet.sol";
import "../../../utils/IERC20.sol";

import {ROLE_ADMIN} from "../../../Constants.sol";
import {AccessControlBase} from "../../../facets/AccessControl/Base.sol";

contract AdminFacet is IAdminFacet, AdminBase, AccessControlBase, Facet {
    function AdminFacet_init() external onlyInitializing {
        _setFunctionAccess(this.setFeeToken.selector, ROLE_ADMIN, true);
        _setFunctionAccess(this.setShouldBurnFeeToken.selector, ROLE_ADMIN, true);
        _setFunctionAccess(this.setMaxFeeRateBps.selector, ROLE_ADMIN, true);
        _setFunctionAccess(this.profitDistribution.selector, ROLE_ADMIN, true);
        _setFunctionAccess(this.setMinimumOrderSalt.selector, ROLE_ADMIN, true);
        _setFunctionAccess(this.setPayment.selector, ROLE_ADMIN, true);
        _setFunctionAccess(this.setMaxSlippageBps.selector, ROLE_ADMIN, true);
        _addInterface(type(IAdminFacet).interfaceId);
    }

    function profitDistribution(
        string memory dateString, // YYYYMMDD
        address profitTokenAddress,
        uint256 brokerageAmount,
        uint256 revenueAmount
    ) external whenNotPaused protected nonReentrant {
        require(s.feeTokenAddressMap[profitTokenAddress], "fee token not enabled");
        require(brokerageAmount > 0 && revenueAmount > 0, "Amount must be greater than 0");

        uint256 amount = s.feeVaultProfitDistributedAmountMap[profitTokenAddress] + brokerageAmount + revenueAmount;
        require(s.feeVaultAmountMap[profitTokenAddress] >= amount, "Insufficient fee vault balance");
        s.feeVaultProfitDistributedAmountMap[profitTokenAddress] = amount;

        // split the revenueAmount into 5 parts: 20%, 15%, 10%, 5%, 50%
        uint256 baseAmount = revenueAmount / 100; // 1%
        uint256 liquidity = baseAmount * 20; // 20%
        uint256 buyBackBurn = baseAmount * 15; // 15%
        uint256 stakingDividends = baseAmount * 10; // 10%
        uint256 riskReserve = baseAmount * 5; // 5%
        uint256 operatingCosts = revenueAmount - (liquidity + buyBackBurn + stakingDividends + riskReserve);

        s.profitVaultMap[PayoutType.brokerage][profitTokenAddress] += brokerageAmount;
        s.profitVaultMap[PayoutType.liquidityFund][profitTokenAddress] += liquidity;
        s.profitVaultMap[PayoutType.buyBackBurnFund][profitTokenAddress] += buyBackBurn;
        s.profitVaultMap[PayoutType.stakingDividendsFund][profitTokenAddress] += stakingDividends;
        s.profitVaultMap[PayoutType.riskReserveFund][profitTokenAddress] += riskReserve;
        s.profitVaultMap[PayoutType.operatingCostsFund][profitTokenAddress] += operatingCosts;

        require(s.profitDistributedLogMap[profitTokenAddress][dateString].isDistributed == false, "Profit already distributed");
        s.profitDistributedLogMap[profitTokenAddress][dateString] = ProfitDistributedDetail({
            isDistributed: true,
            brokerageAmount: brokerageAmount,
            revenueAmount: revenueAmount,
            liquidity: liquidity,
            buyBackBurn: buyBackBurn,
            stakingDividends: stakingDividends,
            riskReserve: riskReserve,
            operatingCosts: operatingCosts
        });

        emit ProfitDistribution(dateString, profitTokenAddress, s.profitDistributedLogMap[profitTokenAddress][dateString]);
    }

    function getProfitDistributedDetail(
        string memory dateString, // YYYYMMDD
        address profitTokenAddress
    ) external view returns (ProfitDistributedDetail memory) {
        require(s.profitDistributedLogMap[profitTokenAddress][dateString].isDistributed == true, "Profit not distributed");
        return s.profitDistributedLogMap[profitTokenAddress][dateString];
    }

    function doPayoutVault(PayoutType payoutType, address to, address feeTokenAddress, uint256 amount) external whenNotPaused protected nonReentrant {
        require(s.feeTokenAddressMap[feeTokenAddress], "Fee token not enabled");
        require(amount > 0, "Amount must be greater than 0");
        // security logic to prevent malicious payout
        uint256 newTotalPayout = s.totalPayoutMap[feeTokenAddress] + amount;
        require(newTotalPayout <= s.maxTotalPayoutMap[feeTokenAddress], "Total payout exceeds max total payout");
        s.totalPayoutMap[feeTokenAddress] = newTotalPayout;

        uint256 newProfitVaultBalance = s.profitVaultMap[payoutType][feeTokenAddress] - amount;
        require(newProfitVaultBalance >= 0, "Insufficient fee vault balance");
        s.profitVaultMap[payoutType][feeTokenAddress] = newProfitVaultBalance;

        // TODO: security logic if amount > maxSinglePayout, add timeLock
        require(IERC20(feeTokenAddress).transfer(to, amount), "Transfer failed");
        emit FeeTokenPayout(payoutType, to, feeTokenAddress, amount);
    }

    function setMaxTotalPayout(address feeTokenAddress, uint256 maxTotalPayout) external whenNotPaused protected nonReentrant {
        require(s.feeTokenAddressMap[feeTokenAddress], "Fee token not enabled");
        require(maxTotalPayout > 0, "Max total payout must be greater than 0");
        s.maxTotalPayoutMap[feeTokenAddress] = maxTotalPayout;
    }

    function setMinimumOrderSalt(uint256 minimumOrderSalt_) external protected {
        s.minimumOrderSalt = minimumOrderSalt_;
    }

    // Only the StableCoin address (or wrap token address) will be set, because feeToken will calculate the fee based on StableCoin
    function setPayment(address val, bool isEnabled) external protected {
        s.paymentAddressMap[val] = isEnabled;
    }

    function setMaxSlippageBps(uint256 maxSlippageBps) external protected {
        s.maxSlippageBps = maxSlippageBps;
    }

    function setFeeToken(address val, uint256 feeTokenPriceStableCoin, bool isEnabled) external protected {
        s.feeTokenAddressMap[val] = isEnabled;
        s.feeTokenPriceStableCoinMap[val] = feeTokenPriceStableCoin;
        emit FeeTokenUpdated(val, feeTokenPriceStableCoin, isEnabled);
    }

    function setShouldBurnFeeToken(address val, bool isEnabled) external protected {
        s.shouldBurnFeeTokenAddressMap[val] = isEnabled;
    }

    function setMaxFeeRateBps(uint256 val) external protected {
        s.maxFeeRateBps = val;
    }

    function getRemainingAmount(Order memory order) external view returns (uint256) {
        bytes32 digest = _hashOrder(order);
        return s.orderRemainingMap[digest];
    }

    function isValidatePayment(address val) external view returns (bool) {
        return s.paymentAddressMap[val];
    }

    function getMaxFeeRateBps() external view returns (uint256 maxFeeRateBps) {
        return s.maxFeeRateBps;
    }

    function getFeeTokenInfo(address val) external view returns (FeeTokenInfo memory) {
        return
            FeeTokenInfo({
                isEnabled: s.feeTokenAddressMap[val],
                priceStableCoin: s.feeTokenPriceStableCoinMap[val],
                shouldBurn: s.shouldBurnFeeTokenAddressMap[val],
                decimals: IERC20(val).decimals(),
                // vault states
                vaultAmount: s.feeVaultAmountMap[val],
                profitDistributedAmount: s.feeVaultProfitDistributedAmountMap[val],
                brokerageVault: s.profitVaultMap[PayoutType.brokerage][val],
                liquidityFundVault: s.profitVaultMap[PayoutType.liquidityFund][val],
                buyBackBurnFundVault: s.profitVaultMap[PayoutType.buyBackBurnFund][val],
                stakingDividendsFundVault: s.profitVaultMap[PayoutType.stakingDividendsFund][val],
                riskReserveFundVault: s.profitVaultMap[PayoutType.riskReserveFund][val],
                operatingCostsFundVault: s.profitVaultMap[PayoutType.operatingCostsFund][val],
                totalPayout: s.totalPayoutMap[val],
                maxTotalPayout: s.maxTotalPayoutMap[val]
            });
    }

    function getFeeTokenPrice(address val) external view returns (uint256 priceStableCoin) {
        return s.feeTokenPriceStableCoinMap[val];
    }

    function getMaxSlippageBps() external view returns (uint256) {
        return s.maxSlippageBps;
    }
}
