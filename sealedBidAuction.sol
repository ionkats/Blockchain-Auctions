pragma solidity ^0.8.3;

contract sealedBidAuction{

    address owner;
    uint256 deposit;
    uint32 numberOfBidders;
    bytes32[] allBids;
    
    constructor(){
        owner = msg.sender;
    }

    // Ethereums hash function keccak256(…) returns (bytes32)
    function addBid(bytes32 bidHash) external{
        allBids.push(bidHash); // list with the hashes of all bids
    }

    // not for using it to encrypt, everything is public the encryption should be localy
    function testBidHash(uint256 bid, string memory salt, bytes32 bidHash) external{
        
    }
}
