// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

contract LendingPool is Ownable, ReentrancyGuard {
    
    struct UserPosition {
        uint256 supplied;
        uint256 borrowed;
    }

    mapping(address => mapping(address => UserPosition)) public positions;
    mapping(address => bool) public supportedTokens;

    event Supplied(address indexed user, address token, uint256 amount);
    event Withdrawn(address indexed user, address token, uint256 amount);
    event Borrowed(address indexed user, address token, uint256 amount);
    event Repaid(address indexed user, address token, uint256 amount);

    constructor() Ownable(msg.sender) {}

    function addToken(address token) external onlyOwner {
        supportedTokens[token] = true;
    }

    function supply(address token, uint256 amount) external nonReentrant {
        require(supportedTokens[token], "Token not supported");
        require(amount > 0, "Amount must be > 0");

        positions[msg.sender][token].supplied += amount;

        bool success = IERC20(token).transferFrom(msg.sender, address(this), amount);
        require(success, "Transfer failed");

        emit Supplied(msg.sender, token, amount);
    }

    function withdraw(address token, uint256 amount) external nonReentrant {
        require(supportedTokens[token], "Token not supported");
        require(amount > 0, "Amount must be > 0");
        require(positions[msg.sender][token].supplied >= amount, "Insufficient supplied balance");

        positions[msg.sender][token].supplied -= amount;

        bool success = IERC20(token).transfer(msg.sender, amount);
        require(success, "Transfer failed");

        emit Withdrawn(msg.sender, token, amount);
    }

    function borrow(address token, uint256 amount) external nonReentrant {
        require(supportedTokens[token], "Token not supported");
        require(amount > 0, "Amount must be > 0");
        
        uint256 poolBalance = IERC20(token).balanceOf(address(this));
        require(poolBalance >= amount, "Insufficient liquidity in pool");

        positions[msg.sender][token].borrowed += amount;

        bool success = IERC20(token).transfer(msg.sender, amount);
        require(success, "Transfer failed");

        emit Borrowed(msg.sender, token, amount);
    }

    function repay(address token, uint256 amount) external nonReentrant {
        require(supportedTokens[token], "Token not supported");
        require(amount > 0, "Amount must be > 0");
        require(positions[msg.sender][token].borrowed >= amount, "Repaying more than borrowed");

        positions[msg.sender][token].borrowed -= amount;

        bool success = IERC20(token).transferFrom(msg.sender, address(this), amount);
        require(success, "Transfer failed");

        emit Repaid(msg.sender, token, amount);
    }
}
