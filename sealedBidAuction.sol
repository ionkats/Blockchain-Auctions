pragma solidity ^0.8.3;
// import "@nomiclabs/builder/console.sol";

contract sealedBidAuction{
    
    //initialized by seller
    uint256 T1;
    uint256 T2;
    uint256 T3;
    uint256 T4;
    uint256 F;
    uint N;
    uint256 V; // upper bound for bids? why?
    uint256 G;
    uint256 H;
    string public state;
    address auctioneer;
    bool auctioneerReturn;
    
    struct Biddings {
        string ciphertext;
        uint256 commit;
        bool validBid;
        bool returned;
    }

    mapping(address => Biddings) bidders;
    address[] listOfBidders;
    uint256 highestBid;
    address winner;
    uint256 timeDeployed;
    uint256 deposit;
    mapping(address => uint256) ledger;
    
    uint256[] zpkCommits;
    address challengeBidder;
    uint challengeBlockNumber;
    
    
    constructor(uint256 t1, uint256 t2, uint256 t3, uint256 t4, uint n, uint256 f, string memory pyblicKey) payable {
        timeDeployed = block.timestamp;
        require(msg.value>=F, "Provide the appropriate payment.");
        require((T1<T2)&&(T2<T3)&&(T3<T4), "Wrong time intervals.");
        deposit = deposit + F ;
        ledger[msg.sender] = msg.value - F;
        T1 = t1;
        T2 = t2;
        T3 = t3;
        T4 = t4;
        N = n;
        state = "Init";
        F = f;
        auctioneer = msg.sender;
    }
    

    function bid(uint256 comm) public payable {
        require((block.timestamp - timeDeployed)<T1, "The commitment period has passed.");
        require(msg.value>F,"Provide at least the appropriate amount.");
        require(listOfBidders.length <= N," No more bidders allowed.");
        ledger[msg.sender] = msg.value - F;
        deposit = deposit + F;
        Biddings storage bidding = bidders[msg.sender];
        listOfBidders.push(msg.sender);
        bidding.commit = comm;
    }
    

    function reveal(string memory cipher) public{
        uint256 time = block.timestamp - timeDeployed;
        require((time>T1)&&(time<T2),"It is not the reveal time.");
        require(bidders[msg.sender].commit != 0, "No commitment was placed in your address");
        bidders[msg.sender].ciphertext = cipher;
    }
    

    function claimWinner(address probWinner, uint256 x, uint256 r) public{
        //hash comparison less gas required compared to string comparison
        require(keccak256(bytes(state))==keccak256("Init"),"Not valid state."); 
        uint256 time = block.timestamp - timeDeployed;
        require((time>T2)&&(time<T3),"It is not the claim the winner time.");
        require(keccak256(bytes(bidders[probWinner].ciphertext)) != keccak256(bytes("")), "Not a bidder."); 
        //also check if x,r are the commit values used by the probWinner.
        // require x*G +r*H == bidders[probWinner].commit for G,H
        // for G,H starting given values
        winner = probWinner;
        highestBid = x;
        state = "Challenge";
    }
    

    function ZPKCommit(address B, uint256[] memory commits) public{
        require(keccak256(bytes(state))==keccak256("Challenge"),"Not valid state.");
        uint256 time = block.timestamp - timeDeployed;
        require((time>T2)&&(time<T3),"It is not the right time.");
        require(keccak256(bytes(bidders[B].ciphertext)) != keccak256(bytes("")), "Not a bidder.");
        zpkCommits = commits;
        challengeBidder = B;
        challengeBlockNumber = block.number;
        state = "Verify";
    }


    function ZPKVerify(uint256[] memory response) public{
        require(keccak256(bytes(state))==keccak256("Verify"), "Not valid state.");
        uint256 time = block.timestamp - timeDeployed;
        require((time>T2)&&(time<T3),"It is not the right time.");
        bytes32 h = keccak256(abi.encodePacked(challengeBlockNumber));
        bytes1 b = h[1];
        if (b==0){
            // first case verification 
        }else{
            // second case verification
        }
        bidders[challengeBidder].validBid = true;
        state = "Challenge";
    }
    

    function VerifyAll() public{
        require(keccak256(bytes(state))==keccak256("Challenge"),"Not valid state.");
        uint256 time = block.timestamp - timeDeployed;
        require((time>T2)&&(time<T3),"It is not the right time.");
        for (uint i; i < listOfBidders.length; i++){
            if (listOfBidders[i] != winner){
                require(bidders[listOfBidders[i]].validBid == true, "There is a non valid bid.");
            }
        }
        state = "ValidWinner";
    }
    

    function WinnerPay() public {
        require(keccak256(bytes(state))==keccak256("ValidWinner"),"Not valid state.");
        uint256 time = block.timestamp - timeDeployed;
        require((time>T3)&&(time<T4),"It is not the right time.");
        require(msg.sender==winner, "You are not the winner.");
        require(ledger[msg.sender] > highestBid-F, "You should pay more.");
        ledger[msg.sender] = ledger[msg.sender] - highestBid + F;
        deposit = deposit + highestBid - F;
        state = "WinnerPaid";
    }


    function Timer() public{
        uint256 time = block.timestamp - timeDeployed;
        if (time>T3){
            if (keccak256(bytes(state))!=keccak256("ValidProof")){
                for (uint i; i < listOfBidders.length; i++){
                    uint256 amount = ledger[listOfBidders[i]];
                    if (bidders[listOfBidders[i]].returned==false){
                        bidders[listOfBidders[i]].returned = true;
                        payable(listOfBidders[i]).transfer(amount + F);
                    }            
                }
            }else{
                uint256 amount = ledger[auctioneer];
                if (auctioneerReturn==false){
                    auctioneerReturn = true;
                    payable(auctioneer).transfer(amount + F);
                }

            }
        }
    }
    
}