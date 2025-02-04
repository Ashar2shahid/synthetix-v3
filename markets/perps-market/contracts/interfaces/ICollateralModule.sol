//SPDX-License-Identifier: MIT
pragma solidity >=0.8.11 <0.9.0;

interface ICollateralModule {
    function setMaxCollateralAmount(uint128 synthId, uint maxCollateralAmount) external;

    function modifyCollateral(uint128 accountId, uint128 synthMarketId, int amountDelta) external;
}
