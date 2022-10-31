//SPDX-License-Identifier: MIT

pragma solidity ^0.8.7;

import "@openzeppelin/contracts-upgradeable/token/ERC721/extensions/ERC721EnumerableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC721/extensions/ERC721BurnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/math/SafeMathUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "./interface/IMissBlockCharmNFT.sol";

//TODO: Change to contract upgradeable when deploy to product

contract MissBlockCharmNFT is IMissBlockCharmNFT, ERC721EnumerableUpgradeable, ERC721BurnableUpgradeable, ReentrancyGuardUpgradeable, OwnableUpgradeable {
    using SafeMathUpgradeable for uint256;

    modifier onlyNotPaused() {
        require(!paused, "Paused");
        _;
    }
    modifier onlyNotBlackListed(uint256 tokenId) {
        require(!blacklist[tokenId], "tokenId blacklisted");
        _;
    }

    mapping(address => mapping(uint256 => mapping(uint256 => Collaborator))) public _collaborators; // adress collab => countryId => tierId => collab info
    mapping(uint256 => bool) public blacklist;

    Country[] private countries; // contain country name and 
    MissBlockCharm[] private _missBlockCharms; // contain countryId and tierId
    Tier[] public tiers; // price per each tier ID
    bool public paused;
    string private _uri;

    function initialize(string memory baseURI) public initializer {
        __ERC721_init("MissBlockCharm", "MBC");
        __Ownable_init();
        _uri = baseURI;
    }

    function togglePaused() external onlyOwner {
        paused = !paused;
    }

    function setBaseURI(string memory baseURI) external onlyOwner {
        _uri = baseURI;
    }

    function addCountry(Country memory country) external onlyOwner {
        countries.push(country);
        uint256 countryId = countries.length - 1;
        emit CountryInfo(countryId, true);
    }
    
    function removeCountry(uint256 countryId) external onlyOwner {
        countries[countryId].isSupported = false;
        emit CountryInfo(countryId, false);
    }

    function addTier(uint256 price, TierDTO[] memory dto) external onlyOwner {
        Tier storage newTier = tiers.push();

        newTier.price = price;

        for(uint256 i = 0; i < dto.length; i++) {
            uint256 countryId = dto[i].countryId;
            uint256 maxSupply = dto[i].maxSupply;
            newTier.maxSupplies[countryId] = maxSupply;
        }

        uint256 tierId = tiers.length - 1;

        emit TierInfo(tierId, dto, price);
    }

    function updateSuppyTier(uint256 tierId, TierDTO[] memory dto) external onlyOwner {
        Tier storage tier = tiers[tierId];

        for(uint256 i = 0; i < dto.length; i++) {
            uint256 countryId = dto[i].countryId;
            uint256 maxSupply = dto[i].maxSupply;

            require(tier.minted[countryId] <= maxSupply);
            tier.maxSupplies[countryId] = maxSupply;
        }

        emit TierInfo(tierId, dto, tier.price);
    }

    function updateTierPrice(uint256 tierId, uint256 price) external onlyOwner {
        Tier storage tier = tiers[tierId];
        tier.price = price;

        emit TierPriceUpdated(tierId, price);
    }

    function getTotalPrice(uint256 amount, uint256 tierId) public view returns(uint256 totalPrice) {
        uint256 pricePerNft = tiers[tierId].price;
        totalPrice = pricePerNft * amount;
    }

    function _baseURI() internal view override returns (string memory) {
        return _uri;
    }

    function setCollaborator(address _contract, CollaboratorDTO[] memory dto)
        external
        onlyOwner
    {
        
        for(uint256 i = 0; i < dto.length; i++) {
            
            uint256 countryId = dto[i].countryId;
            uint256 maxSupply = dto[i].maxSupply;
            uint256 tierId = dto[i].tierId;
            Tier storage tier = tiers[tierId];
            require(countries[countryId].isSupported, "collection not supported");
            require(tier.minted[countryId] + maxSupply <= tiers[tierId].maxSupplies[countryId]);
            tier.minted[countryId] += maxSupply;
            _collaborators[_contract][countryId][tierId] = Collaborator(
                maxSupply,
                0,
                new uint256[](0)
            );
        }
    }

    function _createMissBlockCharm(address owner, uint256 countryId, uint256 tierId) private returns (uint256 missBlockCharmId) {
        _missBlockCharms.push(MissBlockCharm({tierId: tierId, countryId: countryId}));
        missBlockCharmId = _missBlockCharms.length - 1;

        emit MissBlockCharmCreated(missBlockCharmId, countryId, tierId, owner);
    }

    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 tokenId
    ) internal override(ERC721Upgradeable, ERC721EnumerableUpgradeable) {
        require(!paused, "paused");
        require(!blacklist[tokenId], "blacklisted");
        super._beforeTokenTransfer(from, to, tokenId);
    }

    function buy(uint256 amount, address buyer, uint256 countryId, uint256 tierId)
        external
        nonReentrant
        onlyNotPaused
    {
        require(countries[countryId].isSupported, "country not supported");
        Collaborator storage collaborator = _collaborators[msg.sender][countryId][tierId];
        uint256 totalMinted = collaborator.minted.add((amount));

        require(
            collaborator.maxSupply != 0 &&
                totalMinted <= collaborator.maxSupply,
            "invalid collaborator"
        );

        collaborator.minted = totalMinted;

        for (uint256 i = 0; i < amount; i++) {
            uint256 missBlockCharmId = _createMissBlockCharm(buyer, countryId, tierId);
            collaborator.mintedIds.push(missBlockCharmId);
            _safeMint(buyer, missBlockCharmId);
        }
    }

    function supportsInterface(bytes4 interfaceId) public view virtual override(ERC721Upgradeable, ERC721EnumerableUpgradeable) returns (bool) {
        return interfaceId == type(IERC721EnumerableUpgradeable).interfaceId || super.supportsInterface(interfaceId);
    }
}