pragma solidity ^0.8.3;
// import "@nomiclabs/builder/console.sol";

contract sealedBidAuction{
    
    //initialized by seller
    uint256 T1;
    uint256 T2;
    uint256 public F;
    string public state;
    
    struct Biddings {
        bytes32 commit;
        uint256 value;
        bool validBid;
        bool returned;
    }
    mapping(address => Biddings) bidders;
    address[] listOfBidders;
    uint256 secondHighestBid;
    uint256 highestBid;
    address winner;
    uint256 timeDeployed;
    uint256 deposit;
    mapping(address => uint256) ledger;
    address seller;
    bool sellerReturned;
    
    
    constructor(uint256 t1, uint256 t2, uint256 f) payable {
        timeDeployed = block.timestamp;
        require(msg.value>=F, "Provide the appropriate payment.");
        require((T1<T2), "Wrong time intervals.");
        deposit = deposit + F ;
        ledger[msg.sender] = msg.value - F;
        seller = msg.sender;
        T1 = t1;
        T2 = t2;
        state = "Init";
        // F is the penalty if someone tries to manipulate the auction.
        F = f;
    }
    
    
    // called by participants to bid for the item.
    function bid(bytes32 comm) public payable {
        require((block.timestamp - timeDeployed)<T1, "The commitment period has passed.");
        require(msg.value>F,"Provide at least the appropriate amount.");
        ledger[msg.sender] = msg.value - F;
        deposit = deposit + F;
        Biddings memory bidding = bidders[msg.sender];
        listOfBidders.push(msg.sender);
        bidding.commit = comm;
    }
    // called by participants to reveal the value of their bidding.
    function reveal(uint256 v, string memory salt) public{
        uint256 time = block.timestamp - timeDeployed;
        require((time>T1)&&(time<T2),"It is not the reveal time.");
        // checking if the commit is an empty string
        require(bidders[msg.sender].commit[0] != 0, "No commitment was placed in your address");
        // abi.encodePacked concatenates strings and assists in changing the type of v to string.
        if ((bidders[msg.sender].commit) == keccak256(abi.encodePacked( string(abi.encodePacked(bytes32(v))), salt))){
            bidders[msg.sender].validBid = true;
            bidders[msg.sender].value = v;
        }
    }
    
    

    function winnerCalculation() public{
        uint256 time = block.timestamp - timeDeployed;
        require(time>T2,"The reveal time is not done.");
        require(keccak256(bytes(state))!=keccak256("WinnerYes")||keccak256(bytes(state))!=keccak256("WinnerNo"),"Already called.");
        for (uint i=0; i< listOfBidders.length; i++){
            if (bidders[listOfBidders[i]].validBid == true){
                if (bidders[listOfBidders[i]].value>highestBid) {
                    secondHighestBid = highestBid;
                    // the current winner gets his money back. 
                    uint256 amount = ledger[winner];
                    if ((bidders[winner].returned == false)&&(winner!=address(0))){
                        deposit -= F;
                        bidders[winner].returned = true;
                        payable(winner).transfer(amount + F);
                    }
                    highestBid = bidders[listOfBidders[i]].value;
                    winner =listOfBidders[i];
                }
            }else{
                // the bid was not valid, thus the contract keeps the amount F and returns the rest
                uint256 amount = ledger[listOfBidders[i]];
                bidders[listOfBidders[i]].returned = true;
                payable(listOfBidders[i]).transfer(amount);
            }
        }
        
        // refund of the seller if a winner is found, or else the F value is kept by the contract.
        if (winner!=address(0)){
            uint256 amount = ledger[seller];
            if (sellerReturned == false){
                deposit -= F;
                sellerReturned = true;
                payable(seller).transfer(amount+F);
            }
            state = "WinnerYes";
        }else{
            uint256 amount = ledger[seller];
            sellerReturned = true;
            payable(seller).transfer(amount);
            state = "WinnerNo";
        }
        
    }
    
    
    function winnerPaying() public payable{
        require(msg.sender==winner,"You are not the winner");
        require(keccak256(bytes(state))==keccak256("WinnerYes"),"The state isn't WinnerYes.");
        require((msg.value + ledger[msg.sender])>=(secondHighestBid-F),"You must pay more.");
        ledger[winner] += msg.value - secondHighestBid;
        if (bidders[winner].returned == false) {
            uint256 amount = ledger[winner];
            deposit += secondHighestBid-F;
            bidders[winner].returned = true;
            payable(winner).transfer(amount);
        }
        state = "WinnerPaid";
        
    }
    
    
    // function claimWinner(address probWinner) public{
    //     // hash comparison less gas required compared to string comparison
    //     require(keccak256(bytes(state))==keccak256("Init"),"Not valid state."); 
    //     uint256 time = block.timestamp - timeDeployed;
    //     require((time>T2)&&(time<T3),"It is not the claim the winner time.");
    //     require(bidders[probWinner].commit[0] != 0, "Not a bidder."); 
    //     winner = probWinner;
    //     highestBid = bidders[probWinner].value;
    //     state = "Challenge";
    // }
    
}