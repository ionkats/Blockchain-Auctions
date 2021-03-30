pragma solidity ^0.8.3;

// highest bid wins regardless of the price
contract absoluteAuction{

    address seller;
    uint256 maxBid;
    address bidOwner;
    uint256 firstBidTimestamp;
    uint256 timeOfBidding;
    uint256 maxTime;
    

    constructor(uint256 time) payable{
        require(msg.value >= 1 ether, "Pay for the auction service");
        seller = msg.sender;
        maxTime = time;
    }


    function changeMaxTime(uint256 time) external{
        require(msg.sender == seller, "Only the seller can change this value");
        if (bidOwner != address(0)){
            firstBidTimestamp = block.timestamp;
        }
        maxTime = time;
    }


    function addBid(uint256 bid) external{

        if (bidOwner == address(0)) {
            maxBid = bid; 
            bidOwner = msg.sender;
            firstBidTimestamp = block.timestamp;
        } 

        require( (firstBidTimestamp - block.timestamp) < maxTime, "No more bidding");
        if (bid > maxBid){
            maxBid = bid;
            bidOwner = msg.sender;
        }
    }

}