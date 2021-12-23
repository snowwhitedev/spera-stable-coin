// SPDX-License-Identifier: MIT
pragma solidity 0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "./libs/IUpgradedStandardToken.sol";
import "./BlackList.sol";

contract SperaV3 is Ownable, Pausable, BlackList, ERC20 {
    // Called when new token are issued
    event Issue(uint256 amount);
    // Called when tokens are redeemed
    event Redeem(uint256 amount);
    // Called when contract is deprecated
    event Deprecate(address newAddress);

    address public upgradedAddress;
    bool public deprecated;


    //  The contract can be initialized with a number of tokens
    //  All the tokens are deposited to the owner address
    //
    // @param _balance Initial supply of the contract
    // @param _name Token Name
    // @param _symbol Token symbol
    constructor(
        string memory _name,
        string memory _symbol,
        uint256 _initialSupply
    ) ERC20(_name, _symbol) {
        _mint(owner(), _initialSupply);
        deprecated = false;
    }

    function destroyBlackFunds(address _blackListedUser) public override onlyOwner {
        require(isBlackListed[_blackListedUser]);
        uint256 dirtyFunds = balanceOf(_blackListedUser);
        _burn(_blackListedUser, dirtyFunds);
        emit DestroyedBlackFunds(_blackListedUser, dirtyFunds);
    }

    // Forward ERC20 methods to upgraded contract if this one is deprecated
    function transfer(address _to, uint256 _value) public override whenNotPaused returns (bool) {
        require(!isBlackListed[msg.sender], "Blacklisted Memeber");
        if (deprecated) {
            IUpgradedStandardToken(upgradedAddress).transferByLegacy(msg.sender, _to, _value);
        } else {
            super.transfer(_to, _value);
        }
        return true;
    }

    // Forward ERC20 methods to upgraded contract if this one is deprecated
    function transferFrom(
        address _from,
        address _to,
        uint256 _value
    ) public override whenNotPaused returns (bool) {
        require(!isBlackListed[_from], "Blacklisted Member");
        if (deprecated) {
            IUpgradedStandardToken(upgradedAddress).transferFromByLegacy(msg.sender, _from, _to, _value);
        } else {
            super.transferFrom(_from, _to, _value);
        }
        return true;
    }

    // deprecate current contract in favour of a new one
    function deprecate(address _upgradedAddress) public onlyOwner {
        deprecated = true;
        upgradedAddress = _upgradedAddress;
        emit Deprecate(_upgradedAddress);
    }

    // deprecate current contract if favour of a new one
    function totalSupply() public view override returns (uint256) {
        if (deprecated) {
            return IERC20(upgradedAddress).totalSupply();
        } else {
            return super.totalSupply();
        }
    }

    // Issue a new amount of tokens
    // these tokens are deposited into the owner address
    //
    // @param _amount Number of tokens to be issued
    function issue(uint256 amount) external onlyOwner {
        require(totalSupply() + amount > totalSupply(), "Invalide value");
        require(balanceOf(owner()) + amount > balanceOf(owner()), "Invalide value");
        _mint(owner(), amount);
        emit Issue(amount);
    }

    // Redeem tokens.
    // These tokens are withdrawn from the owner address
    // if the balance must be enough to cover the redeem
    // or the call will fail.
    // @param _amount Number of tokens to be issued
    function redeem(uint256 amount) public onlyOwner {
        require(balanceOf(owner()) >= amount);
        _burn(owner(), amount);
        emit Redeem(amount);
    }
}
