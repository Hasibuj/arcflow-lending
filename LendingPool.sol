// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract LendingPool is Ownable {
    
    struct UserPosition {
        uint256 supplied;
        uint256 borrowed;
    }

    mapping(address => mapping(address => UserPosition)) public positions;
    mapping(address => bool) public supportedTokens;

    event Supplied(address indexed user, address token, uint256 amount);
    event Borrowed(address indexed user, address token, uint256 amount);

    constructor() Ownable(msg.sender) {}

    function addToken(address token) external onlyOwner {
        supportedTokens[token] = true;
    }

    function supply(address token, uint256 amount) external {
        require(supportedTokens[token], "Token not supported");
        require(amount > 0, "Amount must be > 0");

        IERC20(token).transferFrom(msg.sender, address(this), amount);
        positions[msg.sender][token].supplied += amount;
        
        emit Supplied(msg.sender, token, amount);
    }

    // বাকি লজিক (Borrow, Withdraw, Repay) পরবর্তীতে এখানে যোগ করা হবে
}
