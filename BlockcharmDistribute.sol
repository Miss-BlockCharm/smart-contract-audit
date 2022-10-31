pragma solidity ^0.8.0;

import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "@openzeppelin/contracts/utils/cryptography/draft-EIP712.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "./utils/TokenWithdrawable.sol";

contract BlockcharmDistribute is
    EIP712,
    AccessControl,
    ReentrancyGuard,
    TokenWithdrawable
{
    using SafeMath for uint256;
    using SafeERC20 for IERC20;

    event Claimed(
        uint256 claimId,
        uint256 totalClaim,
        address receipt,
        address caller
    );

    struct Claimer {
        uint256 totalClaim;
        uint256 claimId;
        address receipt;
        address token;
    }

    bool public paused;
    bytes32 public constant SERVER_ROLE = keccak256("SERVER_ROLE");
    string private constant SIGNING_DOMAIN = "LazyDistribute-MissBlockcharm";
    string private constant SIGNATURE_VERSION = "1";

    mapping(uint256 => bool) private claimedId;

    constructor() EIP712(SIGNING_DOMAIN, SIGNATURE_VERSION) {
        _setupRole(
            DEFAULT_ADMIN_ROLE,
            0x691FE7eeDbD1297bF00b229c2681dd5AC5454fbf //TODO: Change address Admin
        );
        _setupRole(SERVER_ROLE, 0xFFF781b942C19a62683E8A595528e332f684c36A); //TODO: Change address server
    }

    function togglePause() external onlyRole(DEFAULT_ADMIN_ROLE) {
        paused = !paused;
    }

    function claim(Claimer calldata claimer, bytes memory signature)
        external
    {
        address signer = _verify(claimer, signature);
        IERC20 token = IERC20(claimer.token);

        require(!paused, "MBC: paused");
        require(
            hasRole(SERVER_ROLE, signer),
            "MBC: Signature invalid or unauthorized"
        );
        require(!claimedId[claimer.claimId], "MBC: id claimed");

        token.transfer(claimer.receipt, claimer.totalClaim);
        claimedId[claimer.claimId] = true;

        emit Claimed(
            claimer.claimId,
            claimer.totalClaim,
            claimer.receipt,
            msg.sender
        );
    }

    function _hash(Claimer calldata claimer)
        internal
        view
        returns (bytes32)
    {
        return
            _hashTypedDataV4(
                keccak256(
                    abi.encode(
                        keccak256(
                            "Claimer(uint256 totalClaim,uint256 claimId,address receipt,address token)"
                        ),
                        claimer.totalClaim,
                        claimer.claimId,
                        claimer.receipt,
                        claimer.token
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

    function _verify(Claimer calldata claimer, bytes memory signature)
        internal
        view
        returns (address)
    {
        bytes32 digest = _hash(claimer);
        return ECDSA.recover(digest, signature);
    }
}
