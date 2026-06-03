// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract SimpleSwap {
    IERC20 public token;
    uint256 public fee = 30; // 0.3% in basis points
    address public owner;

    event Swap(address indexed user, uint256 amountIn, uint256 amountOut, uint256 deadline);

    constructor(address _token) {
        token = IERC20(_token);
        owner = msg.sender;
    }

    // Swap with slippage protection: minAmountOut + deadline
    function swap(uint256 amountIn, uint256 minAmountOut, uint256 deadline) external {
        require(block.timestamp <= deadline, "Deadline expired");

        uint256 amountOut = amountIn * (10000 - fee) / 10000; // fixed-point precision
        require(amountOut >= minAmountOut, "Slippage exceeded");

        token.transferFrom(msg.sender, address(this), amountIn);
        token.transfer(msg.sender, amountOut);

        emit Swap(msg.sender, amountIn, amountOut, deadline);
    }

    function setFee(uint256 _fee) external {
        require(msg.sender == owner, "Not owner");
        fee = _fee;
    }
}
