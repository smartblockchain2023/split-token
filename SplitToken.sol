// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Context.sol";
import "@openzeppelin/contracts/utils/Address.sol";

contract SplitToken is Context, IERC20, IERC20Metadata, Pausable, Ownable {

    uint256 private _totalSupply;

    string private _name;
    string private _symbol;
    address private _ultimaToken;
    uint private _rewardDelay;

    struct BalanceData {
        uint timestamp;
        uint256 amount;
    }

    mapping(address => BalanceData[]) private _splitBalance;

    error NotImplemented();

    event Reward(address indexed to, uint256 value, bool success);

    /**
     * @dev Sets the values for {name} and {symbol}.
     *
     * The default value of {decimals} is 18. To select a different value for
     * {decimals} you should overload it.
     *
     * All two of these values are immutable: they can only be set once during
     * construction.
     */
    constructor(address ultimaToken_, uint rewardDelay_) {
        _name = "SPLIT";
        _symbol = "SPLIT";
        _ultimaToken = ultimaToken_;
        _rewardDelay = rewardDelay_;
    }

    /**
     * @dev Returns the name of the token.
     */
    function name() public view virtual override returns (string memory) {
        return _name;
    }

    /**
     * @dev Returns the symbol of the token, usually a shorter version of the
     * name.
     */
    function symbol() public view virtual override returns (string memory) {
        return _symbol;
    }

    /**
     * @dev Returns the number of decimals used to get its user representation.
     * For example, if `decimals` equals `2`, a balance of `505` tokens should
     * be displayed to a user as `5.05` (`505 / 10 ** 2`).
     *
     * Tokens usually opt for a value of 18, imitating the relationship between
     * Ether and Wei. This is the value {ERC20} uses, unless this function is
     * overridden;
     *
     * NOTE: This information is only used for _display_ purposes: it in
     * no way affects any of the arithmetic of the contract, including
     * {IERC20-balanceOf} and {IERC20-transfer}.
     */
    function decimals() public view virtual override returns (uint8) {
        return 0;
    }

    function pause() public onlyOwner {
        _pause();
    }

    function unpause() public onlyOwner {
        _unpause();
    }

    function mint(address to, uint256 amount) public onlyOwner {
        _mint(to, amount);
    }

    /**
     * @dev Destroys `amount` tokens from the caller.
     *
     * See {ERC20-_burn}.
     */
    function burn(uint256 amount) public virtual {
        _burn(_msgSender(), amount);
    }

    /**
     * @dev See {IERC20-totalSupply}.
     */
    function totalSupply() public view virtual override returns (uint256) {
        return _totalSupply;
    }

    /**
     * @dev See {IERC20-balanceOf}.
     */
    function balanceOf(address account) public view virtual override returns (uint256) {
        return _getBalance(account);
    }

    /**
     * @dev See {IERC20-transfer}.
     *
     * Requirements:
     *
     * - `to` cannot be the zero address.
     * - the caller must have a balance of at least `amount`.
     */
    function transfer(address to, uint256 amount) public virtual override returns (bool) {
        address owner = _msgSender();
        _transfer(owner, to, amount);
        return true;
    }

    /**
     * @dev See {IERC20-allowance}.
     */
    function allowance(address, address) public view virtual override returns (uint256) {
        revert NotImplemented();
    }

    function getReward() public view virtual returns (uint256) {
        address owner = _msgSender();
        return _getReward(owner);
    }

    function getAllocation() public view virtual returns (BalanceData[] memory) {
        address owner = _msgSender();
        return _splitBalance[owner];
    }

    /**
     * @dev See {IERC20-approve}.
     *
     * NOTE: If `amount` is the maximum `uint256`, the allowance is not updated on
     * `transferFrom`. This is semantically equivalent to an infinite approval.
     *
     * Requirements:
     *
     * - `spender` cannot be the zero address.
     */
    function approve(address, uint256) public virtual override returns (bool) {
        revert NotImplemented();
    }

    function takeReward() public virtual {
        address owner = _msgSender();
        uint256 reward = _getReward(owner);
        bool success = false;

        _setBalance(owner, _getBalance(owner));

        if (reward > 0) {
            bytes memory payload = abi.encodeWithSignature("transfer(address,uint256)", owner, reward);
            // Ignore result
            (success,) = _ultimaToken.call(payload);
        }

        emit Reward(owner, reward, success);
    }

    /**
     * @dev See {IERC20-transferFrom}.
     *
     * Emits an {Approval} event indicating the updated allowance. This is not
     * required by the EIP. See the note at the beginning of {ERC20}.
     *
     * NOTE: Does not update the allowance if the current allowance
     * is the maximum `uint256`.
     *
     * Requirements:
     *
     * - `from` and `to` cannot be the zero address.
     * - `from` must have a balance of at least `amount`.
     * - the caller must have allowance for ``from``'s tokens of at least
     * `amount`.
     */
    function transferFrom(
        address,
        address,
        uint256
    ) public virtual override returns (bool) {
        revert NotImplemented();
    }

    /**
     * @dev Moves `amount` of tokens from `from` to `to`.
     *
     * This internal function is equivalent to {transfer}, and can be used to
     * e.g. implement automatic token fees, slashing mechanisms, etc.
     *
     * Emits a {Transfer} event.
     *
     * Requirements:
     *
     * - `from` cannot be the zero address.
     * - `to` cannot be the zero address.
     * - `from` must have a balance of at least `amount`.
     */
    function _transfer(
        address from,
        address to,
        uint256 amount
    ) internal virtual {
        require(from != address(0), "ERC20: transfer from the zero address");
        require(to != address(0), "ERC20: transfer to the zero address");

        _beforeTokenTransfer(from, to, amount);

        uint256 fromBalance = _getBalance(from);
        require(fromBalance >= amount, "ERC20: transfer amount exceeds balance");

        _setBalance(from, fromBalance - amount);
        _addBalance(to, amount);

        emit Transfer(from, to, amount);

        _afterTokenTransfer(from, to, amount);
    }

    /** @dev Creates `amount` tokens and assigns them to `account`, increasing
     * the total supply.
     *
     * Emits a {Transfer} event with `from` set to the zero address.
     *
     * Requirements:
     *
     * - `account` cannot be the zero address.
     */
    function _mint(address account, uint256 amount) internal virtual {
        require(account != address(0), "ERC20: mint to the zero address");

        _beforeTokenTransfer(address(0), account, amount);

        _totalSupply += amount;
        _addBalance(account, amount);

        emit Transfer(address(0), account, amount);

        _afterTokenTransfer(address(0), account, amount);
    }

    /**
     * @dev Destroys `amount` tokens from `account`, reducing the
     * total supply.
     *
     * Emits a {Transfer} event with `to` set to the zero address.
     *
     * Requirements:
     *
     * - `account` cannot be the zero address.
     * - `account` must have at least `amount` tokens.
     */
    function _burn(address account, uint256 amount) internal virtual {
        require(account != address(0), "ERC20: burn from the zero address");

        _beforeTokenTransfer(account, address(0), amount);

        uint256 accountBalance = _getBalance(account);
        require(accountBalance >= amount, "ERC20: burn amount exceeds balance");

        _setBalance(account, accountBalance - amount);
        _totalSupply -= amount;

        emit Transfer(account, address(0), amount);

        _afterTokenTransfer(account, address(0), amount);
    }

    /**
     * @dev Hook that is called before any transfer of tokens. This includes
     * minting and burning.
     *
     * Calling conditions:
     *
     * - when `from` and `to` are both non-zero, `amount` of ``from``'s tokens
     * will be transferred to `to`.
     * - when `from` is zero, `amount` tokens will be minted for `to`.
     * - when `to` is zero, `amount` of ``from``'s tokens will be burned.
     * - `from` and `to` are never both zero.
     *
     * To learn more about hooks, head to xref:ROOT:extending-contracts.adoc#using-hooks[Using Hooks].
     */
    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 amount
    ) internal whenNotPaused virtual {}

    /**
     * @dev Hook that is called after any transfer of tokens. This includes
     * minting and burning.
     *
     * Calling conditions:
     *
     * - when `from` and `to` are both non-zero, `amount` of ``from``'s tokens
     * has been transferred to `to`.
     * - when `from` is zero, `amount` tokens have been minted for `to`.
     * - when `to` is zero, `amount` of ``from``'s tokens have been burned.
     * - `from` and `to` are never both zero.
     *
     * To learn more about hooks, head to xref:ROOT:extending-contracts.adoc#using-hooks[Using Hooks].
     */
    function _afterTokenTransfer(
        address from,
        address to,
        uint256 amount
    ) internal virtual {}

    function _getBalance(address account) internal view virtual returns (uint256) {
        uint256 balance = 0;
        BalanceData[] memory data = _splitBalance[account];
        for (uint i = 0; i < data.length; i++) {
            balance += data[i].amount;
        }
        return balance;
    }

    function _setBalance(address account, uint256 amount) internal virtual {
        delete _splitBalance[account];
        _addBalance(account, amount);
    }

    function _addBalance(address account, uint256 amount) internal virtual {
        _splitBalance[account].push(BalanceData(block.timestamp, amount));
    }

    function _getReward(address account) internal view virtual returns (uint256) {
        require(_totalSupply > 0, "Total supply should be greater than 0");

        uint currentTimestamp = block.timestamp;
        uint256 oneSecondCost = block.number < 50000001 ? 600 / (2 ** (block.number / 10000000)) : 11;

        BalanceData[] memory balance = _splitBalance[account];
        uint256 total = 0;

        for (uint i = 0; i < balance.length; i++) {
            uint holdingSeconds = currentTimestamp - balance[i].timestamp;
            // only if user hold amount more then 1 day
            if (holdingSeconds >= _rewardDelay && balance[i].amount > 0) {
                total += ((oneSecondCost * holdingSeconds * balance[i].amount) / _totalSupply);
            }
        }

        return total;
    }
}