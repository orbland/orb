// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Address.sol";

contract EricOrb is ERC721, Ownable {
  // Orb params

  uint256 public constant COOLDOWN = 7 days;

  // not mapping, just for tokenId 0
  uint256 public price;

  // System params

  uint256 public constant FEE_DENOMINATOR = 10000; // Basis points
  uint256 public constant HOLDER_TAX_NUMERATOR = 1000; // Harberger tax: 10%...
  uint256 public constant HOLDER_TAX_PERIOD = 365 days; // ...per year
  uint256 public constant SALE_ROYALTIES_NUMERATOR = 1000; // Secondary sale to issuer: 10%

  mapping(address => uint256) private _funds;
  uint256 private _lastSettlementTime; // of the orb holder, shouldn"t be useful is orb is held by contract.

  // Events

  event Deposit(address indexed sender, uint256 amount);
  event Withdrawal(address indexed recipient, uint256 amount);
  event Settlement(address indexed from, address indexed to, uint256 amount);

  event NewPrice(uint256 from, uint256 to);
  event Purchase(address indexed from, address indexed to);
  event Foreclosure(address indexed from);

  constructor() ERC721("EricOrb", "ORB") {
    _safeMint(address(this), 0);
  }

  // ERC-721 compatibility

  function _baseURI() internal pure override returns (string memory) {
    return "https://static.orb.land/eric/";
  }

  // In the future we might allow transfers.
  // It would settle (both accounts in multi-orb) and require the receiver to have deposit.
  function transferFrom(address, address, uint256) public pure override {
    revert("transfering not supported, purchase required");
    // transferFrom(address from, address to, uint256 tokenId) external override onlyOwner onlyOwnerHeld
    // require(_isApprovedOrOwner(_msgSender(), tokenId), "ERC721: caller is not token owner or approved");
    // _transfer(from, to, tokenId);
  }

  function safeTransferFrom(address, address, uint256) public pure override {
    revert("transfering not supported, purchase required");
    // safeTransferFrom(address from, address to, uint256 tokenId) external override onlyOwner onlyOwnerHeld
    // safeTransferFrom(from, to, tokenId, "");
  }

  function safeTransferFrom(address, address, uint256, bytes memory) public pure override {
    revert("transfering not supported, purchase required");
    // safeTransferFrom(address from, address to, uint256 tokenId, bytes memory data)
    //   external override onlyOwner onlyOwnerHeld
    // require(_isApprovedOrOwner(_msgSender(), tokenId), "ERC721: caller is not token owner or approved");
    // _safeTransfer(from, to, tokenId, data);
  }

  // Modifiers

  // inherits onlyOwner

  // Should be use in conjuction with onlyHolderHeld to make sure it"s not the contract
  modifier onlyHolder() {
    address holder = ERC721.ownerOf(0);
    require(_msgSender() == holder, "not orb holder");
    _;
  }

  modifier onlyHolderHeld() {
    address holder = ERC721.ownerOf(0);
    require(address(this) != holder, "contract holds the orb");
    _;
  }

  modifier onlyContractHeld() {
    address holder = ERC721.ownerOf(0);
    require(address(this) == holder, "contract does not hold the orb");
    _;
  }

  modifier onlyHolderInsolvent() {
    require(!_holderSolvent(), "holder solvent");
    _;
  }

  modifier onlyHolderSolvent() {
    require(_holderSolvent(), "holder insolvent");
    _;
  }

  modifier settles() {
    _settle();
    _;
  }

  modifier settlesIfHolder() {
    address holder = ERC721.ownerOf(0);
    if (_msgSender() == holder) {
      _settle();
    }
    _;
  }

  modifier hasFunds() {
    address recipient = _msgSender();
    require(_funds[recipient] > 0, "no funds available");
    _;
  }

  // Key funds manangement methods

  function fundsOf(address user_) external view returns (uint256) {
    require(user_ != address(0), "address zero is not valid");
    return _funds[user_];
  }

  function deposit() external payable {
    address holder = ERC721.ownerOf(0);
    if (_msgSender() == holder) {
      require(_holderSolvent(), "deposits allowed only during solvency");
    }

    _funds[_msgSender()] += msg.value;
    emit Deposit(_msgSender(), msg.value);
  }

  function withdrawAll() external settlesIfHolder hasFunds {
    // auction contract would check notWinningBidder
    _withdraw(_funds[_msgSender()]);
  }

  function withdraw(uint256 amount_) external settlesIfHolder hasFunds {
    // notWinningBidder
    require(_funds[_msgSender()] >= amount_, "not enough funds");
    _withdraw(amount_);
  }

  function _withdraw(uint256 amount_) internal {
    address recipient = _msgSender();
    _funds[recipient] -= amount_;

    emit Withdrawal(recipient, amount_);

    Address.sendValue(payable(recipient), amount_);
  }

  function settle() external onlyHolderHeld {
    _settle();
  }

  function min(uint256 a, uint256 b) internal pure returns (uint256) {
    return a <= b ? a : b;
  }

  function _settle() internal {
    address holder = ERC721.ownerOf(0);

    if (owner() == holder) {
      return;
      // Owner doesn"t need to pay themselves
    }

    assert(address(this) != holder); // should never be reached if contract holds the orb

    uint256 availableFunds = _funds[holder];
    uint256 transferableToOwner = min(availableFunds, _owedSinceLastSettlement());
    _funds[holder] -= transferableToOwner;
    _funds[owner()] += transferableToOwner;

    _lastSettlementTime = block.timestamp;

    emit Settlement(holder, owner(), transferableToOwner);
  }

  // Orb Selling

  function setPrice(uint256 newPrice_) external onlyHolder onlyHolderHeld onlyHolderSolvent settles {
    _setPrice(newPrice_);
  }

  function _setPrice(uint256 newPrice_) internal {
    uint256 oldPrice = price;
    price = newPrice_;
    emit NewPrice(oldPrice, newPrice_);
  }

  // function minimumAcceptedPurchaseAmount() external view returns (uint256) {
  //   uint256 minimumDeposit = (price * holderTaxNumerator) / feeDenominator;
  //   return price + minimumDeposit;
  // }

  function purchase(
    uint256 currentPrice_,
    uint256 newPrice_
  ) external payable onlyHolderHeld onlyHolderSolvent settles {
    // require current price to prevent front-running
    require(currentPrice_ == price, "current price incorrect");

    // just to prevent errors, price can be set to 0 later
    require(newPrice_ > 0, "new price cannot be zero when purchasing");

    address holder = ERC721.ownerOf(0);
    require(_msgSender() != holder, "you already own the orb");

    _funds[_msgSender()] += msg.value;
    uint256 totalFunds = _funds[_msgSender()];

    // requires more than price -- not specified how much more, expects UI to handle
    require(totalFunds > price, "not enough funds");
    // require(totalFunds >= minimumAcceptedPurchaseAmount(), "not enough funds");

    uint256 ownerRoyalties = (price * SALE_ROYALTIES_NUMERATOR) / FEE_DENOMINATOR;
    uint256 currentOwnerShare = price - ownerRoyalties;

    _funds[_msgSender()] -= price;
    _funds[owner()] += ownerRoyalties;
    _funds[holder] += currentOwnerShare;

    _transfer(holder, _msgSender(), 0);
    _lastSettlementTime = block.timestamp;

    _setPrice(newPrice_);

    emit Purchase(holder, _msgSender());
  }

  // Foreclosure

  function exit() external onlyHolder onlyHolderHeld onlyHolderSolvent settles {
    _transfer(_msgSender(), address(this), 0);
    price = 0;

    emit Foreclosure(_msgSender());

    _withdraw(_funds[_msgSender()]);
  }

  function foreclose() external onlyHolderHeld onlyHolderInsolvent settles {
    address holder = ERC721.ownerOf(0);
    _transfer(holder, address(this), 0);
    price = 0;

    emit Foreclosure(holder);
  }

  function foreclosureTime() external view onlyHolderHeld returns (uint256) {
    return _foreclosureTime();
  }

  function holderSolvent() external view onlyHolderHeld returns (bool) {
    return _holderSolvent();
  }

  // Internal calculations

  function _owedSinceLastSettlement() internal view returns (uint256) {
    uint256 secondsSinceLastSettlement = block.timestamp - _lastSettlementTime;
    return (price * HOLDER_TAX_NUMERATOR * secondsSinceLastSettlement) / (HOLDER_TAX_PERIOD * FEE_DENOMINATOR);
  }

  function _holderSolvent() internal view returns (bool) {
    address holder = ERC721.ownerOf(0);
    if (owner() == holder) {
      return true;
    }
    return _funds[holder] > _owedSinceLastSettlement();
  }

  function _foreclosureTime() internal view returns (uint256) {
    address holder = ERC721.ownerOf(0);
    if (owner() == holder) {
      return 0;
    }

    // uint256 costPerPeriod = price * holderTaxNumerator / feeDenominator;
    // uint256 costPerSecond = costPerPeriod / holderTaxPeriod;
    // uint256 remainingSeconds = _funds[holder] / costPerSecond;
    // return _lastSettlementTime + remainingSeconds;

    uint256 remainingSeconds = (_funds[holder] * HOLDER_TAX_PERIOD * FEE_DENOMINATOR) / (price * HOLDER_TAX_NUMERATOR);
    return _lastSettlementTime + remainingSeconds;
  }
}