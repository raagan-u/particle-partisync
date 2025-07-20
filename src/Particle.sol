// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.28;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract Particle is ERC20, Ownable {

    mapping(address => bool) private _blacklist;
    mapping(address => bool) private _whitelist;
    
    event Blacklisted(address indexed account);
    event Whitelisted(address indexed account);

    constructor(address initialOwner) ERC20("Particle", "PTCL") Ownable(initialOwner) {
        _mint(msg.sender, 10000000 * 10 ** decimals());
    }

    function decimals() public view virtual override returns (uint8) {
        return 8;
    }

    function mint(address to, uint256 amount) external onlyOwner {
        _mint(to, amount);
    }

    function burn(uint256 amount) external onlyOwner {
        _burn(msg.sender, amount);
    }

    function burnFrom(address account, uint256 amount) external onlyOwner {
        _burn(account, amount);
    }

    function blacklist(address account) external onlyOwner {
        require(!_blacklist[account], "Account is already blacklisted");
        _blacklist[account] = true;
        emit Blacklisted(account);
    }

    function whitelist(address account) external onlyOwner {
        require(!_whitelist[account], "Account is already whitelisted");
        _whitelist[account] = true;
        emit Whitelisted(account);
    }

    function removeFromBlacklist(address account) external onlyOwner {
        require(_blacklist[account], "Account is not blacklisted");
        _blacklist[account] = false;
        emit Blacklisted(account);
    }

    function removeFromWhitelist(address account) external onlyOwner {
        require(_whitelist[account], "Account is not whitelisted");
        _whitelist[account] = false;
        emit Whitelisted(account);
    }

    function isBlacklisted(address account) external view returns (bool) {
        return _blacklist[account];
    }

    function isWhitelisted(address account) external view returns (bool) {
        return _whitelist[account];
    }

    function _transfer(address from, address to, uint256 amount) internal virtual override {
        require(!_blacklist[from], "Sender is blacklisted");
        require(!_blacklist[to], "Recipient is blacklisted");
        super._transfer(from, to, amount);
    }
}
