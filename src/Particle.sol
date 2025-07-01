// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.28;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract Particle is ERC20, Ownable {

    mapping(address => bool) private _blacklist;

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

    function blacklist(address account) external onlyOwner {
        require(!_blacklist[account], "Account is already blacklisted");
        _blacklist[account] = true;
        emit Blacklisted(account);
    }
}
