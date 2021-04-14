pragma solidity ^0.8.3;
// import "@nomiclabs/builder/console.sol";

// highest bid wins regardless of the price
contract absoluteAuction{

    address public seller;
    uint256 public maxBid;
    address public bidOwner;
    address previousBidder;

    // time variables
    uint256 firstTimestamp;
    uint256 public maxTime;
    uint256 public timeAdded;

    
    // keeps the addresses and the values of the smaller bids
    mapping(address => uint) getMoneyBack;

    // no changes after the end of the auction process, initialized as false by default
    bool public ended;
    bool public finalCallvalue;
    
    // Events that will be emitted on changes.
    event HighestBidIncreased(address bidder, uint bid);
    event EndOfAuction(address winner, uint bid);

    // when the contract is made, the owner is the seller and gives 
    // the time period in seconds of the bidding
    constructor(uint256 time){
        // require(msg.value >= 1 ether, "Pay for the auction service");
        seller = msg.sender;
        maxTime = time;
        firstTimestamp = block.timestamp;
    }

    // changing the bidding time to allow more bidders to play
    function changeMaxTime(uint256 time) public{
        require(msg.sender == seller, "Only the seller can change this value");
        require(!finalCallvalue,"No extra time given.");
        require(!ended, "Auction ended.");
        maxTime = time;
        firstTimestamp = block.timestamp;
    }

    // includes the payment, for binding purposes
    function addBid() public payable{
        
        require((block.timestamp - firstTimestamp) < (maxTime +timeAdded), "No more bidding");
        require(!ended, "Auction ended.");
        require(msg.value>maxBid, "Bid higher");
        
        if (maxBid != 0) {
            previousBidder = bidOwner;  
        }
        
        getMoneyBack[msg.sender] = msg.value;
        bidOwner = msg.sender;
        maxBid = msg.value;
        emit HighestBidIncreased(msg.sender, msg.value);
        
        addTime();
        
        if (previousBidder != address(0)){
            // the current bidOwner gets his money back, because a higher bid is made
            bool check = payable(previousBidder).send(getMoneyBack[previousBidder]);
            if (check){
                delete getMoneyBack[previousBidder];
            }
        }
    }
    
    // the bid is retuned after a higher bid is made, is it doesn't succeed each bidder 
    // can also call this function to take his money back. No doublespending problem each mapping is deleted.
    function getBack(address bidder) public returns(bool){
        require(ended,"Auction not ended.");
        require(bidder!=bidOwner,"You are the winner, no returns.");
        uint256 amount = getMoneyBack[bidder];
        if (amount > 0){
            getMoneyBack[bidder] = 0;
            // if the sending doesn't work it resets the value in the mapping 
            // and returns false
            if (!payable(bidder).send(amount)){
                getMoneyBack[bidder] = amount;
                return false;
            }
        }
        return true;
    }
    
    function addTime() internal{
         if (!finalCallvalue){
            //if there are less than 5 minutes to bid left
            if (maxTime + timeAdded < 300 + (block.timestamp - firstTimestamp)){
                //allow 300sec=5min  more for bidding
                timeAdded = 300 - maxTime + block.timestamp - firstTimestamp;
            }
         }
    }

    // end the auction
    function endAuction() public{
        // console.log("Time remaining",block.timestamp - firstTimestamp," - ",maxTime+timeAdded);
        require(!ended, "Auction ended.");
        require((block.timestamp - firstTimestamp) > (maxTime+timeAdded), "There is available time.");

        ended = true;
        emit EndOfAuction(bidOwner, maxBid);
        getMoneyBack[bidOwner] = 0; //the winner cannot get his money back.
        payable(seller).transfer(maxBid);
        // remains to send the item to the winner
    }
    
    function finalCall() public{
        require(!ended, "Auction ended.");
        require(msg.sender == seller,"Only the seller can call this function");
        addTime();
        finalCallvalue = true;
    }
}