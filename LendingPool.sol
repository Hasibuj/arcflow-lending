// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @dev Minimal ERC20 interface for interaction with stablecoins like USDC/EURC
 */
interface IERC20 {
    function transferFrom(address sender, address recipient, uint256 amount) external returns (bool);
    function transfer(address recipient, uint256 amount) external returns (bool);
    function balanceOf(address account) external view returns (uint256);
}

/**
 * @title ArcFlow Lending Pool
 * @notice Core contract managing deposits, borrowing, repayments, and liquidations.
 * @dev Deployed native on Arc Network focusing on stablecoin capital efficiency.
 */
contract LendingPool {
    
    // --- Custom Errors (Gas Optimized) ---
    error ZeroAmountNotAllowed();
    error TokenNotSupported();
    error TransferFailed();
    error InsufficientCollateral();
    error HealthFactorTooLow();

    // --- Structs ---
    struct UserPosition {
        uint256 suppliedBalance;
        uint256 borrowedBalance;
    }

    // --- State Variables ---
    address public owner;
    address[] public trackedAssets; // Stores all whitelisted tokens for health factor calculation
    
    // Supported Assets: Asset Address => Supported status
    mapping(address => bool) public isAssetSupported;
    
    // User Positions: User => Asset => Position Details
    mapping(address => mapping(address => UserPosition)) public userPositions;

    // Collateral Factor (e.g., 80% LTV = 8000)
    uint256 public constant COLLATERAL_FACTOR = 8000; 
    uint256 public constant BPS_DIVIDER = 10000;

    // --- Events ---
    event Supply(address indexed user, address indexed asset, uint256 amount);
    event Withdraw(address indexed user, address indexed asset, uint256 amount);
    event Borrow(address indexed user, address indexed asset, uint256 amount);
    event Repay(address indexed user, address indexed asset, uint256 amount);

    modifier onlyOwner() {
        if (msg.sender != owner) revert("Not owner");
        _;
    }

    modifier onlySupportedAsset(address asset) {
        if (!isAssetSupported[asset]) revert(TokenNotSupported());
        _;
    }

    constructor() {
        owner = msg.sender;
    }

    /**
     * @notice Admin function to whitelist assets like USDC or EURC
     * @param asset The address of the token to support
     */
    function addAssetSupport(address asset) external onlyOwner {
        if (!isAssetSupported[asset]) {
            isAssetSupported[asset] = true;
            trackedAssets.push(asset);
        }
    }

    /**
     * @notice Allows users to supply stablecoins as collateral to earn interest
     * @param asset The address of the asset being supplied
     * @param amount The amount to supply
     */
    function supply(address asset, uint256 amount) external onlySupportedAsset(asset) {
        if (amount == 0) revert(ZeroAmountNotAllowed());

        userPositions[msg.sender][asset].suppliedBalance += amount;
        emit Supply(msg.sender, asset, amount);

        bool success = IERC20(asset).transferFrom(msg.sender, address(this), amount);
        if (!success) revert(TransferFailed());
    }

    /**
     * @notice Allows users to withdraw their supplied assets if they have enough collateral
     * @param asset The address of the asset to withdraw
     * @param amount The amount to withdraw
     */
    function withdraw(address asset, uint256 amount) external onlySupportedAsset(asset) {
        if (amount == 0) revert(ZeroAmountNotAllowed());
        if (userPositions[msg.sender][asset].suppliedBalance < amount) revert(InsufficientCollateral());

        userPositions[msg.sender][asset].suppliedBalance -= amount;

        // Check if the user's position remains safe after withdrawal across all assets
        if (getHealthFactor(msg.sender) < 1e18) revert(HealthFactorTooLow());

        emit Withdraw(msg.sender, asset, amount);

        bool success = IERC20(asset).transfer(msg.sender, amount);
        if (!success) revert(TransferFailed());
    }

    /**
     * @notice Allows users to borrow stablecoins against their collateral
     * @param asset The address of the asset to borrow
     * @param amount The amount to borrow
     */
    function borrow(address asset, uint256 amount) external onlySupportedAsset(asset) {
        if (amount == 0) revert(ZeroAmountNotAllowed());

        userPositions[msg.sender][asset].borrowedBalance += amount;

        // Validate that borrowing this amount doesn't breach LTV bounds
        if (getHealthFactor(msg.sender) < 1e18) revert(HealthFactorTooLow());

        emit Borrow(msg.sender, asset, amount);

        bool success = IERC20(asset).transfer(msg.sender, amount);
        if (!success) revert(TransferFailed());
    }

    /**
     * @notice Repays a borrowed asset debt
     * @param asset The address of the asset being repaid
     * @param amount The amount to repay
     */
    function repay(address asset, uint256 amount) external onlySupportedAsset(asset) {
        if (amount == 0) revert(ZeroAmountNotAllowed());
        
        uint256 userDebt = userPositions[msg.sender][asset].borrowedBalance;
        uint256 repayAmount = amount > userDebt ? userDebt : amount;

        userPositions[msg.sender][asset].borrowedBalance -= repayAmount;
        emit Repay(msg.sender, asset, repayAmount);

        bool success = IERC20(asset).transferFrom(msg.sender, address(this), repayAmount);
        if (!success) revert(TransferFailed());
    }

    /**
     * @notice Calculates the aggregate Health Factor of a user across all supported assets. 
     * @dev Value >= 1e18 means safe. Below 1e18 means open for liquidation.
     * @param user The address of the protocol user
     * @return The health factor scaled by 1e18
     */
    function getHealthFactor(address user) public view returns (uint256) {
        uint256 totalCollateralValue = 0;
        uint256 totalBorrowedValue = 0;

        // Loop through all tracked assets to calculate aggregated portfolio state
        for (uint256 i = 0; i < trackedAssets.length; i++) {
            address asset = trackedAssets[i];
            totalCollateralValue += userPositions[user][asset].suppliedBalance;
            totalBorrowedValue += userPositions[user][asset].borrowedBalance;
        }

        if (totalBorrowedValue == 0) return 100e18; // Complete safe factor if no debt exists

        uint256 collateralAdjustedValue = (totalCollateralValue * COLLATERAL_FACTOR) / BPS_DIVIDER;
        return (collateralAdjustedValue * 1e18) / totalBorrowedValue;
    }
}
