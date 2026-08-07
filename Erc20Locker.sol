// SPDX-License-Identifier: UNLICENSED

pragma solidity =0.8.24;

import "./library/AccessControlUpgradeableEx.sol";

import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

contract Erc20Locker is AccessControlUpgradeableEx {
    using SafeERC20 for IERC20;

    address public token_;
    uint256 public duration_;
    uint256 public amount_;
    bool public open_;

    mapping(address user => uint256 unlockTimestamp) public userDeposits_;

    event Stake(address indexed user, uint256 lockTimestamp);
    event Unstake(address indexed user, uint256 timestamp);

    function version() external pure returns (string memory) { return "Erc20Locker v1.0"; }

    constructor() {
        _disableInitializers();
    }

    function initialize(
        address _admin,
        address _token,
        uint256 _duration,
        uint256 _amount
    ) external initializer {
        _grantRole(DEFAULT_ADMIN_ROLE, _admin);

        require(_token != address(0), "L-1: zero token address");
        require(_duration > 0, "L-2: zero duration");
        require(_amount > 0, "L-3: zero amount");
        token_ = _token;
        duration_ = _duration;
        amount_ = _amount;
    }

    function openDeposits(bool _open) external onlyRole(DEFAULT_ADMIN_ROLE) {
        require(open_ != _open, "L-4: already done");
        open_ = _open;
    }

    function canStake(address _user) external view returns (bool) {
        return open_ && userDeposits_[_user] == 0;
    }

    function canUnstake(address _user) external view returns (bool) {
        uint256 unlockTimestamp = userDeposits_[_user];
        return unlockTimestamp != 0 && block.timestamp >= unlockTimestamp;
    }

    function stake() external {
        require(open_, "L-5: closed");

        address operator = _msgSender();
        require(userDeposits_[operator] == 0, "L-6: already staked");

        IERC20(token_).safeTransferFrom(operator, address(this), amount_);
        userDeposits_[operator] = block.timestamp + duration_;

        emit Stake(operator, block.timestamp);
    }

    function unstake() external {
        address operator = _msgSender();

        uint256 unlockTimestamp = userDeposits_[operator];
        require(unlockTimestamp != 0, "L-7: not staked");
        require(block.timestamp >= unlockTimestamp, "L-8: not ready yet");

        delete userDeposits_[operator];
        IERC20(token_).safeTransfer(operator, amount_);

        emit Unstake(operator, block.timestamp);
    }
}