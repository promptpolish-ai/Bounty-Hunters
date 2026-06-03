// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";

contract PriceOracle {
    AggregatorV3Interface public primaryOracle;
    AggregatorV3Interface public fallbackOracle;
    uint256 public maxStaleness = 3600; // 1 hour default
    address public owner;

    event StalePrice(address indexed oracle, uint256 lastUpdate);

    modifier onlyOwner() {
        require(msg.sender == owner, "Not owner");
        _;
    }

    constructor(address _primary, address _fallback) {
        primaryOracle = AggregatorV3Interface(_primary);
        fallbackOracle = AggregatorV3Interface(_fallback);
        owner = msg.sender;
    }

    function setMaxStaleness(uint256 _maxStaleness) external onlyOwner {
        maxStaleness = _maxStaleness;
    }

    function getPrice() external view returns (uint256) {
        (uint256 price, uint256 updatedAt, bool valid) = _tryOracle(primaryOracle);
        if (valid) return price;

        emit StalePrice(address(primaryOracle), updatedAt);

        (uint256 fallbackPrice, uint256 fallbackUpdatedAt, bool fallbackValid) = _tryOracle(fallbackOracle);
        require(fallbackValid, "Both oracles stale");
        
        emit StalePrice(address(fallbackOracle), fallbackUpdatedAt);
        return fallbackPrice;
    }

    function _tryOracle(AggregatorV3Interface oracle) internal view returns (uint256 price, uint256 updatedAt, bool valid) {
        try oracle.latestRoundData() returns (
            uint80 roundId,
            int256 answer,
            uint256 /* startedAt */,
            uint256 _updatedAt,
            uint80 answeredInRound
        ) {
            if (answer <= 0) return (0, 0, false);
            if (answeredInRound < roundId) return (0, 0, false);
            if (block.timestamp - _updatedAt > maxStaleness) return (0, _updatedAt, false);
            return (uint256(answer), _updatedAt, true);
        } catch {
            return (0, 0, false);
        }
    }
}
