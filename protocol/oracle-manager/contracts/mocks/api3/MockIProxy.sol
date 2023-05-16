//SPDX-License-Identifier: MIT
pragma solidity >=0.8.11 <0.9.0;

import "../../interfaces/external/IApi3Proxy.sol";

contract MockIProxy is IApi3Proxy {
    int224 private price;
    uint32 private timestamp;
    address private api3Server = address(bytes20(bytes("API3_SERVER_V1")));

    constructor(int224 _price) {
        timestamp = uint32(block.timestamp);
        price = _price;
    }

    function read() external view returns (int224, uint32) {
        return (price, timestamp);
    }

    function api3ServerV1() external view returns (address) {
        return api3Server;
    }
}
