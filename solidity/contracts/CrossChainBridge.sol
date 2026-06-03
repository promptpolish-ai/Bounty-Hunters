// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
contract CrossChainBridge {
    IERC20 public bridgeToken; address public validator;
    bytes32 public constant DOMAIN_TYPEHASH = keccak256("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)");
    bytes32 public constant TRANSFER_TYPEHASH = keccak256("Transfer(address recipient,uint256 amount,uint256 nonce)");
    bytes32 public domainSeparator; string public constant NAME = "CrossChainBridge"; string public constant VERSION = "1";
    mapping(address => uint256) public senderNonces;
    mapping(bytes32 => bool) public processedTransfers;
    event TransferInitiated(address indexed sender, uint256 amount, uint256 targetChain, uint256 nonce);
    event TransferProcessed(bytes32 indexed transferHash, address indexed recipient, uint256 amount);
    constructor(address _bridgeToken, address _validator) {
        bridgeToken = IERC20(_bridgeToken); validator = _validator;
        domainSeparator = keccak256(abi.encode(DOMAIN_TYPEHASH, keccak256(bytes(NAME)), keccak256(bytes(VERSION)), block.chainid, address(this)));
    }
    function initiateTransfer(uint256 amount, uint256 targetChain) external {
        require(amount > 0, "Amount must be > 0");
        bridgeToken.transferFrom(msg.sender, address(this), amount);
        emit TransferInitiated(msg.sender, amount, targetChain, senderNonces[msg.sender]++);
    }
    function _buildTransferHash(address r, uint256 a, uint256 n) internal view returns (bytes32) {
        return keccak256(abi.encodePacked("\x19\x01", domainSeparator, keccak256(abi.encode(TRANSFER_TYPEHASH, r, a, n))));
    }
    function processTransfer(address recipient, uint256 amount, bytes calldata sig) external {
        uint256 sn = senderNonces[recipient];
        bytes32 h = _buildTransferHash(recipient, amount, sn);
        require(!processedTransfers[h], "Already processed");
        require(verifySignature(h, sig), "Invalid signature");
        processedTransfers[h] = true; senderNonces[recipient] = sn + 1;
        bridgeToken.transfer(recipient, amount);
        emit TransferProcessed(h, recipient, amount);
    }
    function verifySignature(bytes32 hash, bytes calldata sig) public view returns (bool) {
        require(sig.length == 65, "Invalid signature length");
        bytes32 r; bytes32 s; uint8 v;
        assembly { r := calldataload(sig.offset); s := calldataload(add(sig.offset,32)); v := byte(0, calldataload(add(sig.offset,64))); }
        if (v < 27) v += 27;
        address recovered = ecrecover(hash, v, r, s);
        require(recovered != address(0), "Invalid signature: zero address");
        return recovered == validator;
    }
    function getSenderNonce(address sender) external view returns (uint256) { return senderNonces[sender]; }
    function getPoolBalance() external view returns (uint256) { return bridgeToken.balanceOf(address(this)); }
}
