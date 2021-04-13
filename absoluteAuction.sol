pragma solidity ^0.8.3;

// highest bid wins regardless of the price
contract absoluteAuction{

    address seller;
    uint256 public maxBid;
    address public bidOwner;
    address payable bidder;

    // time variables
    uint256 firstTimestamp;
    uint256 public maxTime;

    // returns of the smaller bids
    mapping(address => uint) getMoneyBack;

    // no changes after the end of the auction process, initialized as false by default
    bool public ended;
    
    // Events that will be emitted on changes.
    event HighestBidIncreased(address bidder, uint bid);
    event EndOfAuction(address winner, uint bid);

    // when the contract is made, the owner is the seller and gives 
    // the time period in seconds of the bidding
    constructor(uint256 time) payable{
        require(msg.value >= 1 ether, "Pay for the auction service");
        seller = msg.sender;
        maxTime = time;
        firstTimestamp = block.timestamp;
    }

    // changing the bidding time to allow more bidders to play
    function changeMaxTime(uint256 time) public{
        require(msg.sender == seller, "Only the seller can change this value");
        maxTime = time;
        firstTimestamp = block.timestamp;
    }

    // includes the payment, for binding purposes
    function addBid() public payable{
        
        require((firstTimestamp - block.timestamp) < maxTime, "No more bidding");
        require(ended==false, "The auction has ended");
        require(msg.value>maxBid, "Bid higher");

        if (maxBid != 0) {
            getMoneyBack[bidOwner] = maxBid;
        }

        bidOwner = msg.sender;
        maxBid = msg.value;
        emit HighestBidIncreased(msg.sender, msg.value);
    }
    
    // each bidder calls this function to take his money back
    function getBack() public returns(bool){
        uint256 amount = getMoneyBack[msg.sender];
        if (amount > 0){
            getMoneyBack[msg.sender] = 0;
            // if the sending doesn't work it resets the value in the mapping 
            // and returns false
            bidder = payable(address(msg.sender));
            if ( !bidder.send(amount) ){
                getMoneyBack[msg.sender] = amount;
                return false;
            }
        }
        return true;
    }

    // end the auction
    function endAuction() public{
        require(!ended,"The auction has already ended.");
        require((firstTimestamp - block.timestamp) > maxTime, "The auction time not ended yet.");

        ended = true;
        emit EndOfAuction(bidOwner, maxBid);
        address payable seller = payable(address(seller));
        seller.transfer(maxBid);
        // remains to send the item to the winner
    }
}