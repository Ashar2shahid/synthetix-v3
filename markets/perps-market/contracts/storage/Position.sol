//SPDX-License-Identifier: MIT
pragma solidity >=0.8.11 <0.9.0;

import {SafeCastI256, SafeCastU256, SafeCastI128, SafeCastU128} from "@synthetixio/core-contracts/contracts/utils/SafeCast.sol";
import {DecimalMath} from "@synthetixio/core-contracts/contracts/utils/DecimalMath.sol";
import {LiquidationConfiguration} from "./LiquidationConfiguration.sol";
import {PerpsMarket} from "./PerpsMarket.sol";
import {PerpsPrice} from "./PerpsPrice.sol";
import {PerpsMarketConfiguration} from "./PerpsMarketConfiguration.sol";
import {MathUtil} from "../utils/MathUtil.sol";

library Position {
    using SafeCastI256 for int256;
    using SafeCastU256 for uint256;
    using SafeCastI128 for int128;
    using SafeCastU128 for uint128;
    using DecimalMath for int256;
    using DecimalMath for uint256;
    using DecimalMath for int128;
    using PerpsMarket for PerpsMarket.Data;
    using LiquidationConfiguration for LiquidationConfiguration.Data;
    using PerpsMarketConfiguration for PerpsMarketConfiguration.Data;

    struct Data {
        uint128 marketId;
        int128 size;
        uint128 latestInteractionPrice;
        int128 latestInteractionFunding;
    }

    function updatePosition(Data storage self, Data memory newPosition) internal {
        self.size = newPosition.size;
        self.marketId = newPosition.marketId;
        self.latestInteractionPrice = newPosition.latestInteractionPrice;
        self.latestInteractionFunding = newPosition.latestInteractionFunding;
    }

    function clear(Data storage self) internal {
        self.size = 0;
        self.latestInteractionPrice = 0;
        self.latestInteractionFunding = 0;
    }

    function getPositionData(
        Data storage self,
        uint price
    )
        internal
        view
        returns (int notional, int pnl, int accruedFunding, int netFundingPerUnit, int nextFunding)
    {
        PerpsMarket.Data storage perpsMarket = PerpsMarket.load(self.marketId);

        nextFunding = perpsMarket.lastFundingValue + perpsMarket.unrecordedFunding(price);
        netFundingPerUnit = nextFunding - self.latestInteractionFunding;

        accruedFunding = self.size.mulDecimal(netFundingPerUnit);

        int priceShift = price.toInt() - self.latestInteractionPrice.toInt();
        pnl = self.size.mulDecimal(priceShift) + accruedFunding;

        notional = getNotionalSize(self, price);
    }

    function getNotionalSize(Data storage self, uint price) internal view returns (int) {
        return self.size.mulDecimal(price.toInt());
    }

    function getLiquidationAmount(Data storage self) internal view returns (uint) {
        if (self.marketId == 0) {
            return 0;
        }

        uint price = PerpsPrice.getCurrentPrice(self.marketId);
        int size = self.size;
        return
            LiquidationConfiguration.load(self.marketId).liquidationMargin(
                MathUtil.abs(size.mulDecimal(price.toInt()))
            ) + PerpsMarketConfiguration.load(self.marketId).liquidationPremium(size, price);
    }
}
