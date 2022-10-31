//SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

interface IMissBlockCharmNFT {
    event CountryInfo(uint256 collectionId, bool isSupported);
    event MissBlockCharmCreated(uint256 missBlockCharmId, uint256 countryId, uint256 tierId, address owner);
    event TierInfo(uint256 tierId, TierDTO[] tierInfo, uint256 price);
    event TierPriceUpdated(uint256 tierId, uint256 price);

    struct Collaborator {
        uint256 maxSupply;
        uint256 minted;
        uint256[] mintedIds;
    }

    struct CollaboratorDTO {
        uint256 tierId;
        uint256 countryId;
        uint256 maxSupply;
    }
    struct Tier {
        mapping(uint256 => uint256) maxSupplies; //mapping countryId => maxSupply
        mapping(uint256 => uint256) minted; 
        uint256 price;
    }

    struct TierDTO {
        uint256 maxSupply;
        uint256 countryId;
    }

    struct MissBlockCharm {
        uint256 tierId;
        uint256 countryId;
    }

    struct Country {
        string name;
        bool isSupported;
    }

    function buy(uint256 amount, address buyer, uint256 countryId, uint256 tierId) external;
}