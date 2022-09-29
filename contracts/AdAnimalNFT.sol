//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;
pragma experimental ABIEncoderV2;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Burnable.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Pausable.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC1155/IERC1155.sol";
import "@openzeppelin/contracts/token/ERC1155/utils/ERC1155Holder.sol";
import "@openzeppelin/contracts/token/ERC1155/utils/ERC1155Receiver.sol";
import "@openzeppelin/contracts/access/AccessControlEnumerable.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/utils/Context.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";

/**
 * @dev {ERC721} token, including:
 *
 *  - ability for holders to burn (destroy) their tokens
 *  - a minter role that allows for token minting (creation)
 *  - token ID and URI autogeneration
 *
 * This contract uses {AccessControl} to lock permissioned functions using the
 * different roles - head to its documentation for details.
 *
 * The account that deploys the contract will be granted the minter and pauser
 * roles, as well as the default admin role, which will let it grant both minter
 * and pauser roles to other accounts.
 */
contract AdAnimalNFT is
    Context,
    AccessControlEnumerable,
    ERC721Enumerable,
    ERC721URIStorage,
    ERC1155Holder
{
    using Counters for Counters.Counter;
    using EnumerableSet for EnumerableSet.UintSet;
    using SafeMath for uint256;
    using SafeERC20 for IERC20;

    Counters.Counter public _tokenIdTracker;

    // Define AdAnimal struct
    struct AdAnimal {
        address prevOwner;
        address currentOwner;
        uint256 price;
    }
    struct PriceInfo {
        bool forSale;
        uint256 price;
    }

    string private _baseTokenURI;
    uint256 private _price;
    uint256 private _max;
    address private _admin;
    uint256 public rewardFee; // 500 => 5%, 10000 => 100%
    address public treasuryAddress;
    uint256 public treasuryAvailableUntilTimestamp; // Timestamp

    uint256 public reflectionBalance;
    uint256 public totalReward;
    mapping(uint256 => uint256) public lastRewardAt;
    mapping(uint256 => address) public minter;

    // TokenID set
    mapping(uint256 => EnumerableSet.UintSet) transferTimestamp;
    // AdAnimalNFT transferHistory
    mapping(uint256 => mapping(uint256 => AdAnimal)) public transferHistory;
    // Current price info of the NFT
    mapping(uint256 => PriceInfo) public curPriceInfo;
    // Number of rarity Types
    uint256 public totalRarityType; // RarityType start from 1
    // Save all the token's rarity (tokenId -> rarity)
    mapping(uint256 => uint256) private _rarity;
    // Save the rarity of each token minted so far.
    mapping(uint256 => uint256) private _rarityTokenCount;

    // Mapping if certain name string has already been reserved
    mapping(string => bool) private _nameReserved;
    // Mapping from token ID to name
    mapping(uint256 => string) private _tokenName;
    // Name change token address
    address private _nctAddress;
    // Name change price
    // uint256 public constant NAME_CHANGE_PRICE = 1830 * (10**18);
    uint256 public nameChangePrice;

    // Mapping from token ID to nft type
    mapping(uint256 => uint256) private _tokenType;
    address private _tctAddress;

    // Events
    event NFTPreMinted(address owner, uint256 tokenId);
    event NFTMinted(address owner, uint256 tokenId, uint256 timestamp);
    event NFTListed(
        address owner,
        uint256 tokenId,
        uint256 price,
        uint256 timestamp
    );
    event NFTChangePrice(
        address owner,
        uint256 tokenId,
        uint256 price,
        uint256 timestamp
    );
    event NFTCancelList(address owner, uint256 tokenId, uint256 timestamp);
    event NFTTraded(
        address prevOwner,
        address newOwner,
        uint256 tokenId,
        uint256 price,
        uint256 timestamp
    );
    event AlternativeClaimed(address owner, uint256 amount);
    event NameChange(uint256 indexed maskIndex, string newName);
    event TypeChange(uint256 index, uint256 tokenType);

    constructor(
        string memory name,
        string memory symbol,
        string memory baseTokenURI,
        uint256 mintPrice,
        uint256 max,
        address admin,
        uint256 totalRarityType_,
        uint256 rewardFee_,
        address treasuryAddress_,
        uint256 treasuryAvailableUntilTimestamp_,
        uint256 nameChangePrice_
    ) ERC721(name, symbol) {
        _baseTokenURI = baseTokenURI;
        _price = mintPrice;
        _max = max;
        _admin = admin;
        totalRarityType = totalRarityType_;
        rewardFee = rewardFee_;
        treasuryAddress = treasuryAddress_;
        treasuryAvailableUntilTimestamp = treasuryAvailableUntilTimestamp_;
        nameChangePrice = nameChangePrice_;

        _setupRole(DEFAULT_ADMIN_ROLE, admin);
    }

    function _baseURI() internal view virtual override returns (string memory) {
        return _baseTokenURI;
    }

    function setBaseURI(string memory baseURI) external {
        require(
            hasRole(DEFAULT_ADMIN_ROLE, _msgSender()),
            "AdAnimalNFT: must have admin role to change base URI"
        );
        _baseTokenURI = baseURI;
    }

    function setTokenURI(uint256 tokenId, string memory _tokenURI) external {
        require(
            hasRole(DEFAULT_ADMIN_ROLE, _msgSender()),
            "AdAnimalNFT: must have admin role to change token URI"
        );
        _setTokenURI(tokenId, _tokenURI);
    }

    function setPrice(uint256 mintPrice) external {
        require(
            hasRole(DEFAULT_ADMIN_ROLE, _msgSender()),
            "AdAnimalNFT: must have admin role to change price"
        );
        _price = mintPrice;
    }

    function setAdmin(address admin) external {
        require(
            hasRole(DEFAULT_ADMIN_ROLE, _msgSender()),
            "AdAnimalNFT: must have admin role to set admin"
        );
        grantRole(DEFAULT_ADMIN_ROLE, admin);
        _admin = admin;
    }

    function setMaxTokenAmount(uint256 amount) external {
        require(
            hasRole(DEFAULT_ADMIN_ROLE, _msgSender()),
            "AdAnimalNFT: must have admin role to set _max"
        );
        _max = amount;
    }

    function setTotalRarityType(uint256 rarityType) external {
        require(
            hasRole(DEFAULT_ADMIN_ROLE, _msgSender()),
            "AdAnimalNFT: must have admin role to change totalRarityType"
        );
        totalRarityType = rarityType;
    }

    function setRewardFee(uint256 rewardF) external {
        require(
            hasRole(DEFAULT_ADMIN_ROLE, _msgSender()),
            "AdAnimalNFT: must have admin role to set rewardFee"
        );
        rewardFee = rewardF;
    }

    function setTreasuryAddress(address treasuryAddr) external {
        require(
            hasRole(DEFAULT_ADMIN_ROLE, _msgSender()),
            "AdAnimalNFT: must have admin role to set treasury address"
        );
        treasuryAddress = treasuryAddr;
    }

    function setNctAddress(address nctAddress) external {
        require(
            hasRole(DEFAULT_ADMIN_ROLE, _msgSender()),
            "AdAnimalNFT: must have admin role to set nct address"
        );
        _nctAddress = nctAddress;
    }

    function setTctAddress(address tctAddress) external {
        require(
            hasRole(DEFAULT_ADMIN_ROLE, _msgSender()),
            "AdAnimalNFT: must have admin role to set tct address"
        );
        _tctAddress = tctAddress;
    }

    function setNameChangePrice(uint256 nameChangePrice_) external {
        require(
            hasRole(DEFAULT_ADMIN_ROLE, _msgSender()),
            "AdAnimalNFT: must have admin role to set name change price"
        );
        nameChangePrice = nameChangePrice_;
    }

    function setTreasuryAvailableUntilTimestamp(uint256 availableUntil)
        external
    {
        require(
            hasRole(DEFAULT_ADMIN_ROLE, _msgSender()),
            "AdAnimalNFT: must have admin role to set treasury available until timestamp"
        );
        treasuryAvailableUntilTimestamp = availableUntil;
    }

    function setTokenIDsRarity(uint256 rarity, uint256[] memory tokenIds)
        external
    {
        require(
            hasRole(DEFAULT_ADMIN_ROLE, _msgSender()),
            "AdAnimalNFT: must have admin role to set the token rarity"
        );
        require(rarity >= 0, "AdAnimalNFT: rarity should bigger than 0");
        require(
            rarity < totalRarityType,
            "AdAnimalNFT: rarity can't bigger than totalRarity"
        );
        require(
            tokenIds.length > 0,
            "AdAnimalNFT: should have 1 token id at least"
        );

        for (uint256 i = 0; i < tokenIds.length; i++) {
            _rarity[tokenIds[i]] = rarity;
        }
        _rarityTokenCount[rarity] += tokenIds.length;
    }

    function price() public view returns (uint256) {
        return _price;
    }

    function preMint(uint256 amount, address receiverAddr) public {
        require(
            hasRole(DEFAULT_ADMIN_ROLE, _msgSender()),
            "AdAnimalNFT: must have admin role to premint the NFT"
        );
        uint256 timestamp = block.timestamp;

        for (uint256 i = 0; i < amount; i++) {
            uint256 _curTokenId = _tokenIdTracker.current();
            _mint(receiverAddr, _curTokenId);
            minter[_curTokenId] = msg.sender;
            lastRewardAt[_curTokenId] = totalReward;

            AdAnimal memory newAdAnimal = AdAnimal(address(0), receiverAddr, 0);
            transferHistory[_curTokenId][timestamp] = newAdAnimal;
            transferTimestamp[_curTokenId].add(timestamp);

            _tokenIdTracker.increment();
            emit NFTPreMinted(receiverAddr, _curTokenId);
        }
    }

    function mint(uint256 amount) public payable {
        require(
            msg.value == _price * amount,
            "AdAnimalNFT: must send correct price"
        );
        require(
            _tokenIdTracker.current() + amount <= _max,
            "AdAnimalNFT: not enough AdAnimalNFTs left to mint amount"
        );
        uint256 timestamp = block.timestamp;

        for (uint256 i = 0; i < amount; i++) {
            uint256 _curTokenId = _tokenIdTracker.current();
            _mint(msg.sender, _curTokenId);
            minter[_curTokenId] = msg.sender;
            lastRewardAt[_curTokenId] = totalReward;

            // // Increase the rarityCount
            // uint256 prevCount = _rarityTokenCount[_rarity[_curTokenId]];
            // _rarityTokenCount[_rarity[_curTokenId]] = prevCount + 1;

            AdAnimal memory newAdAnimal = AdAnimal(
                address(0),
                msg.sender,
                _price
            );
            transferHistory[_curTokenId][timestamp] = newAdAnimal;
            transferTimestamp[_curTokenId].add(timestamp);
            PriceInfo memory newPriceInfo = PriceInfo(false, _price);
            curPriceInfo[_curTokenId] = newPriceInfo;

            uint256 amountPerOne = msg.value / amount;
            // Disabling the rewardShare in mint phase
            // uint256 rewardShare = (amountPerOne * rewardFee) / 10000;
            // reflectReward(rewardShare);
            // sendFundToAdmin(amountPerOne - rewardShare);
            sendFundToAdmin(amountPerOne);

            _tokenIdTracker.increment();
            emit NFTMinted(msg.sender, _curTokenId, timestamp);
        }
    }

    function tokenMinter(uint256 tokenId) public view returns (address) {
        return minter[tokenId];
    }

    function _burn(uint256 tokenId)
        internal
        virtual
        override(ERC721, ERC721URIStorage)
    {
        return ERC721URIStorage._burn(tokenId);
    }

    function tokenURI(uint256 tokenId)
        public
        view
        override(ERC721, ERC721URIStorage)
        returns (string memory)
    {
        return ERC721URIStorage.tokenURI(tokenId);
    }

    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 tokenId
    ) internal virtual override(ERC721, ERC721Enumerable) {
        if (totalSupply() > tokenId) claimReward(tokenId);
        super._beforeTokenTransfer(from, to, tokenId);
    }

    /**
     * @dev See {IERC165-supportsInterface}.
     */
    function supportsInterface(bytes4 interfaceId)
        public
        view
        virtual
        override(
            AccessControlEnumerable,
            ERC721,
            ERC721Enumerable,
            ERC1155Receiver
        )
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }

    function currentRate() public view returns (uint256) {
        if (totalSupply() == 0) return 0;
        return reflectionBalance / totalSupply();
    }

    function claimRewards() public {
        uint256 count = balanceOf(msg.sender);
        uint256 balance = 0;
        for (uint256 i = 0; i < count; i++) {
            uint256 tokenId = tokenOfOwnerByIndex(msg.sender, i);
            balance += getReflectionBalance(tokenId);
            lastRewardAt[tokenId] = totalReward;
        }
        payable(msg.sender).transfer(balance);
    }

    // This function send the reward to the specific address and then will count.
    function claimRewardsAlternative() public {
        require(
            block.timestamp < treasuryAvailableUntilTimestamp,
            "AdAnimalNFT: treasury ended. can't claim rewards alternatively"
        );

        uint256 count = balanceOf(msg.sender);
        uint256 balance = 0;
        for (uint256 i = 0; i < count; i++) {
            uint256 tokenId = tokenOfOwnerByIndex(msg.sender, i);
            balance += getReflectionBalance(tokenId);
            lastRewardAt[tokenId] = totalReward;
        }
        payable(treasuryAddress).transfer(balance);
        emit AlternativeClaimed(msg.sender, balance);
    }

    function getReflectionBalances() public view returns (uint256) {
        uint256 count = balanceOf(msg.sender);
        uint256 total = 0;
        for (uint256 i = 0; i < count; i++) {
            uint256 tokenId = tokenOfOwnerByIndex(msg.sender, i);
            total += getReflectionBalance(tokenId);
        }
        return total;
    }

    function claimReward(uint256 tokenId) public {
        uint256 balance = getReflectionBalance(tokenId);
        payable(ownerOf(tokenId)).transfer(balance);
        lastRewardAt[tokenId] = totalReward;
    }

    function getReflectionBalance(uint256 tokenId)
        public
        view
        returns (uint256)
    {
        require(
            tokenId < _tokenIdTracker.current(),
            "AdAnimalNFT: can't get the reflection balance of unminted nft"
        );
        uint256 rareType = _rarity[tokenId];
        if (rareType >= totalRarityType) {
            return 0;
        } else {
            return
                (totalReward - lastRewardAt[tokenId]) *
                (totalRarityType - rareType);
        }
    }

    function sendFundToAdmin(uint256 amount) private {
        payable(_admin).transfer(amount);
    }

    function reflectReward(uint256 amount) private {
        reflectionBalance = reflectionBalance + amount;
        uint256 totalAmount = 0;

        for (uint256 i = 0; i < totalRarityType; i++) {
            totalAmount += (totalRarityType - i) * _rarityTokenCount[i];
        }

        totalReward = totalReward + amount.div(totalAmount);
    }

    function reflectToOwners() public payable {
        reflectReward(msg.value);
    }

    /**
     * NameChange related functions
     */

    function toLower(string memory str) public pure returns (string memory) {
        bytes memory bStr = bytes(str);
        bytes memory bLower = new bytes(bStr.length);
        for (uint256 i = 0; i < bStr.length; i++) {
            // Uppercase character
            if ((uint8(bStr[i]) >= 65) && (uint8(bStr[i]) <= 90)) {
                bLower[i] = bytes1(uint8(bStr[i]) + 32);
            } else {
                bLower[i] = bStr[i];
            }
        }
        return string(bLower);
    }

    function toggleReserveName(string memory str, bool isReserve) internal {
        _nameReserved[toLower(str)] = isReserve;
    }

    function isNameReserved(string memory nameString)
        public
        view
        returns (bool)
    {
        return _nameReserved[toLower(nameString)];
    }

    function tokenNameByIndex(uint256 index)
        public
        view
        returns (string memory)
    {
        return _tokenName[index];
    }

    function validateName(string memory str) public pure returns (bool) {
        bytes memory b = bytes(str);
        if (b.length < 1) return false;
        if (b.length > 25) return false; // Cannot be longer than 25 characters
        if (b[0] == 0x20) return false; // Leading space
        if (b[b.length - 1] == 0x20) return false; // Trailing space

        bytes1 lastChar = b[0];

        for (uint256 i; i < b.length; i++) {
            bytes1 char = b[i];

            if (char == 0x20 && lastChar == 0x20) return false; // Cannot contain continous spaces

            if (
                !(char >= 0x30 && char <= 0x39) && //9-0
                !(char >= 0x41 && char <= 0x5A) && //A-Z
                !(char >= 0x61 && char <= 0x7A) && //a-z
                !(char == 0x20) //space
            ) return false;

            lastChar = char;
        }

        return true;
    }

    function changeName(uint256 tokenId, string memory newName) public {
        address owner = ownerOf(tokenId);

        require(_msgSender() == owner, "ERC721: caller is not the owner");
        require(validateName(newName) == true, "Not a valid new name");
        require(
            sha256(bytes(newName)) != sha256(bytes(_tokenName[tokenId])),
            "New name is same as the current one"
        );
        require(isNameReserved(newName) == false, "Name already reserved");

        // TODO: Where the NCT Tokens should go.
        IERC20(_nctAddress).transferFrom(
            msg.sender,
            address(this), // need to replaced with reserveAddress
            nameChangePrice
        );
        // If already named, dereserve old name
        if (bytes(_tokenName[tokenId]).length > 0) {
            toggleReserveName(_tokenName[tokenId], false);
        }
        toggleReserveName(newName, true);
        _tokenName[tokenId] = newName;

        emit NameChange(tokenId, newName);
    }

    /**
     * NFT Type related functions
     */

    function changeType(uint256 tokenId, uint256 tokenType) public {
        address owner = ownerOf(tokenId);
        // Check msg.sender is the owner of this NFT.
        require(_msgSender() == owner, "Caller is not the owner");
        // Check if this NFT has the type
        require(_tokenType[tokenId] == 0, "This NFT has already tokenType");
        // Check msg sender has the tokenType (1155)
        uint256 balance = IERC1155(_tctAddress).balanceOf(
            msg.sender,
            tokenType
        );
        require(
            balance > 0,
            "Msg sender doesn't have the required ERC1155 token"
        );
        IERC1155(_tctAddress).safeTransferFrom(
            msg.sender,
            address(this),
            tokenType,
            1,
            ""
        );
        _tokenType[tokenId] = tokenType;
        emit TypeChange(tokenId, tokenType);
    }

    function removeType(uint256 tokenId) public {
        address owner = ownerOf(tokenId);
        // Check msg.sender is the owner of this NFT.
        require(_msgSender() == owner, "Caller is not the owner");
        // Check if this NFT has the type
        uint256 tokenType = _tokenType[tokenId];
        require(tokenType > 0, "This NFT doesn't have type");
        // Check cur contract has the enough tokenType
        uint256 balance = IERC1155(_tctAddress).balanceOf(
            address(this),
            tokenType
        );
        require(
            balance > 0,
            "This contract doesn't have the required ERC1155 token"
        );
        IERC1155(_tctAddress).safeTransferFrom(
            address(this),
            msg.sender,
            tokenType,
            1,
            ""
        );
        _tokenType[tokenId] = 0;
        emit TypeChange(tokenId, 0);
    }

    function tokenTypeByIndex(uint256 index) public view returns (uint256) {
        return _tokenType[index];
    }

    /**
     * MarketPlace related functions
     */

    function getTradingHistory(uint256 tokenId)
        public
        view
        returns (AdAnimal[] memory)
    {
        require(
            transferTimestamp[tokenId].length() > 0,
            "AdAnimalNFT: Trading History doesn't exist"
        );
        AdAnimal[] memory _tradingHistory = new AdAnimal[](
            transferTimestamp[tokenId].length()
        );
        for (uint256 i = 0; i < transferTimestamp[tokenId].length(); i++) {
            uint256 _timestamp = transferTimestamp[tokenId].at(i);
            _tradingHistory[i] = transferHistory[tokenId][_timestamp];
        }
        return _tradingHistory;
    }

    function buyNFT(uint256 tokenId) public payable {
        // check if the function caller is not an zero account address
        require(msg.sender != address(0));
        // check if the token id of the token being bought exists or not
        require(_exists(tokenId));
        // get the token's owner
        address tokenOwner = ownerOf(tokenId);
        // token's owner should not be an zero address account
        require(tokenOwner != address(0));
        // the one who wants to buy the token should not be the token's owner
        require(tokenOwner != msg.sender);
        PriceInfo memory priceInfo = curPriceInfo[tokenId];
        // price sent in to buy should be equal to or more than the token's price
        require(msg.value >= priceInfo.price);
        // token should be for sale
        require(priceInfo.forSale);

        _transfer(tokenOwner, msg.sender, tokenId);

        uint256 rewardShare = (msg.value * rewardFee) / 10000;

        reflectReward(rewardShare);

        payable(tokenOwner).transfer(msg.value - rewardShare);

        AdAnimal memory newAdAnimal = AdAnimal(
            tokenOwner,
            msg.sender,
            msg.value
        );
        transferHistory[tokenId][block.timestamp] = newAdAnimal;
        transferTimestamp[tokenId].add(block.timestamp);
        priceInfo.forSale = false;
        curPriceInfo[tokenId] = priceInfo;
        emit NFTTraded(tokenOwner, msg.sender, tokenId, msg.value, block.timestamp);
    }

    function createListing(
        uint256 tokenId,
        uint256 newPrice,
        bool forSale
    ) public {
        // require caller of the function is not an empty address
        require(msg.sender != address(0));
        // require that token should exist
        require(_exists(tokenId));
        // get the token's owner
        address tokenOwner = ownerOf(tokenId);
        // check that token's owner should be equal to the caller of the function
        require(tokenOwner == msg.sender);
        // get that token from all curPriceInfo mapping and create a memory of it defined as (struct => CryptoBoy)
        PriceInfo memory priceInfo = curPriceInfo[tokenId];
        // update token's price with new price
        priceInfo.price = newPrice;
        priceInfo.forSale = forSale;
        // set and update that token in the mapping
        curPriceInfo[tokenId] = priceInfo;
        emit NFTListed(msg.sender, tokenId, newPrice, block.timestamp);
    }

    function changeTokenPrice(uint256 tokenId, uint256 newPrice) public {
        // require caller of the function is not an empty address
        require(msg.sender != address(0));
        // require that token should exist
        require(_exists(tokenId));
        // get the token's owner
        address tokenOwner = ownerOf(tokenId);
        // check that token's owner should be equal to the caller of the function
        require(tokenOwner == msg.sender);
        // get that token from all curPriceInfo mapping and create a memory of it defined as (struct => CryptoBoy)
        PriceInfo memory priceInfo = curPriceInfo[tokenId];
        // update token's price with new price
        priceInfo.price = newPrice;
        // set and update that token in the mapping
        curPriceInfo[tokenId] = priceInfo;
        emit NFTChangePrice(msg.sender, tokenId, newPrice, block.timestamp);
    }

    // switch between set for sale and set not for sale
    function cancelListing(uint256 tokenId) public {
        // require caller of the function is not an empty address
        require(msg.sender != address(0));
        // require that token should exist
        require(_exists(tokenId));
        // get the token's owner
        address tokenOwner = ownerOf(tokenId);
        // check that token's owner should be equal to the caller of the function
        require(tokenOwner == msg.sender);
        // get that token from all curPriceInfo mapping and create a memory of it defined as (struct => CryptoBoy)
        PriceInfo memory priceInfo = curPriceInfo[tokenId];
        require(priceInfo.forSale, "AdAnimalNFT: not listed for sale");

        priceInfo.forSale = false;
        // set and update that token in the mapping
        curPriceInfo[tokenId] = priceInfo;
        emit NFTCancelList(msg.sender, tokenId, block.timestamp);
    }
}
