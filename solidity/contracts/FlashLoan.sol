// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract FlashLoan {
    IERC20 public token;
    uint256 public feeBPS = 9; // 0.09% in basis points
    address public owner;
    bool public paused;

    uint256 private _internalBalance;

    modifier onlyOwner() {
        require(msg.sender == owner, "Not owner");
        _;
    }

    modifier whenNotPaused() {
        require(!paused, "Paused");
        _;
    }

    event FlashLoan(address indexed user, uint256 amount, uint256 fee);

    constructor(address _token) {
        token = IERC20(_token);
        owner = msg.sender;
        _internalBalance = 0;
    }

    function flashLoan(uint256 amount, bytes calldata data) external whenNotPaused returns (bool) {
        uint256 balanceBefore = token.balanceOf(address(this));
        require(amount <= balanceBefore / 2, "Exceeds max loan (50% of pool)");

        uint256 fee = amount * feeBPS / 10000;
        if (fee == 0) fee = 1; // minimum fee of 1 token unit

        // Track internal balance for rebasing token protection
        _internalBalance = balanceBefore;

        token.transfer(msg.sender, amount);

        (bool success, ) = msg.sender.call(data);
        require(success, "Callback failed");

        uint256 balanceAfter = token.balanceOf(address(this));
        require(balanceAfter >= _internalBalance + fee, "Fee not paid");

        emit FlashLoan(msg.sender, amount, fee);
        return true;
    }

    function pause() external onlyOwner {
        paused = true;
    }

    function unpause() external onlyOwner {
        paused = false;
    }

    function setFeeBPS(uint256 _feeBPS) external onlyOwner {
        feeBPS = _feeBPS;
    }

    function getPoolBalance() external view returns (uint256) {
        return token.balanceOf(address(this));
    }
}
