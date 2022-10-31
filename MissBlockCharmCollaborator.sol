//SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/cryptography/draft-EIP712.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "./interface/IMissBlockCharmNFT.sol";


contract MissBlockCharmCollaborator is EIP712, AccessControl {
    using SafeERC20 for IERC20;

    modifier onlyNotPaused() {
        require(!paused, "Paused");
        _;
    }

    IMissBlockCharmNFT public nftContract = IMissBlockCharmNFT(0xF1dbEddA8885292A9cafeaeC9A14ede53828A445);//TODO: define address of NFT contract

    bytes32 public constant SERVER_ROLE = keccak256("SERVER_ROLE");
    bytes32 public constant CONTROLLER_ROLE = keccak256("CONTROLLER_ROLE");
    string private constant SIGNING_DOMAIN = "LazyCollaborator-MissBlockCharm";
    string private constant SIGNATURE_VERSION = "1";
    address public receiver;
    bool public paused;

    struct Buyer {
        uint256 amount;
        address buyerAddress;
        uint256 totalPrice;
        address tokenAddress;
        uint256 countryId;
        uint256 tierId;
    }

    constructor() EIP712(SIGNING_DOMAIN, SIGNATURE_VERSION) {
        _setupRole(
            DEFAULT_ADMIN_ROLE,
            msg.sender
        );
        _setupRole(CONTROLLER_ROLE, 0xD93C0D33f84eABB8222E0705AE7e3bcdff9BEEbb);
        _setupRole(SERVER_ROLE, 0xD93C0D33f84eABB8222E0705AE7e3bcdff9BEEbb);
        receiver = 0xD93C0D33f84eABB8222E0705AE7e3bcdff9BEEbb;
    }

    function togglePause() external onlyRole(CONTROLLER_ROLE) {
        paused = !paused;
    }

    function setAddressReceiver(address _receiver) external onlyRole(CONTROLLER_ROLE) {
        require(_receiver != address(0));
        receiver = _receiver;
    }

    function setNFTContract(IMissBlockCharmNFT _nftContract) external onlyRole(CONTROLLER_ROLE) {
        nftContract = _nftContract;
    }

    function buy(Buyer calldata buyer, bytes memory signature)  external payable onlyNotPaused {
        address signer = _verify(buyer, signature);
        bool isNativeToken = buyer.tokenAddress == address(0);
        IERC20 token = IERC20(buyer.tokenAddress);

        uint256 amount = buyer.amount;
        uint256 totalPrice = buyer.totalPrice;

        require(buyer.buyerAddress == msg.sender, "invalid signature");
        require(
            hasRole(SERVER_ROLE, signer),
            "Signature invalid or unauthorized"
        );
        if(isNativeToken) {
            require(msg.value == totalPrice, "not enough fee");
            (bool isSuccess, ) = address(receiver).call{value: totalPrice}("");
            require(isSuccess);
        } else {
            token.safeTransferFrom(msg.sender, receiver, totalPrice);
        }

        
        nftContract.buy(amount, buyer.buyerAddress, buyer.countryId, buyer.tierId);
    }

    function _hash(Buyer calldata buyer)
        internal
        view
        returns (bytes32)
    {
        return
            _hashTypedDataV4(
                keccak256(
                    abi.encode(
                        keccak256(
                            "Buyer(uint256 amount,address buyerAddress,uint256 totalPrice,address tokenAddress,uint256 countryId,uint256 tierId)"
                        ),
                        buyer.amount,
                        buyer.buyerAddress,
                        buyer.totalPrice,
                        buyer.tokenAddress,
                        buyer.countryId,
                        buyer.tierId
                    )
                )
            );
    }

    function getChainID() external view returns (uint256) {
        uint256 id;
        assembly {
            id := chainid()
        }
        return id;
    }

    function _verify(Buyer calldata buyer, bytes memory signature)
        internal
        view
        returns (address)
    {
        bytes32 digest = _hash(buyer);
        return ECDSA.recover(digest, signature);
    }
}