pragma solidity ^0.8.3;
// import "@nomiclabs/builder/console.sol";

contract sealedBidAuction{
    
    //initialized by seller
    uint256 T1;
    uint256 T2;
    uint256 T3;
    uint256 T4;
    uint256 F;
    uint256 G = 7;
    uint256 H = 3;
    uint256 q=21888242871839275222246405745257275088696311157297823662689037894645226208583;
    uint16 k = 1; // (times the protocol is implemented) defines the prob of cheating 1/ 2^k 
    uint counter;
    string public state;
    address auctioneer;
    bool auctioneerReturn;
    string public pubKey;
    
    struct Biddings {
        string ciphertext;
        uint256 commit;
        bool validBid;
        bool validDelta;
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
    
    
    constructor(uint256 t1, uint256 t2, uint256 t3, uint256 t4, uint256 f, string memory publicKey) payable {
        timeDeployed = block.timestamp;
        require(msg.value>=F, "Provide the appropriate payment.");
        require((T1<T2)&&(T2<T3)&&(T3<T4), "Wrong time intervals.");
        deposit = deposit + F ;
        ledger[msg.sender] = msg.value - F;
        T1 = t1;
        T2 = t2;
        T3 = t3;
        T4 = t4;
        // N = n;
        pubKey = publicKey;
        state = "Init";
        F = f;
        auctioneer = msg.sender;
    }
    
    
    // assuming the commit phase each participant sends a of value xG+rH
    // x bid, r random modq
    // w1 in [0,q/2], w2 = w1 - q/2, x bid
    function bid(uint256 comm) public payable {
        require((block.timestamp - timeDeployed)<T1, "The commitment period has passed.");
        require(msg.value>=F,"Provide at least the appropriate amount.");
        require(msg.value<q/2,"Provide at least the appropriate amount.");
        ledger[msg.sender] = msg.value - F;
        deposit = deposit + F;
        Biddings storage bidding = bidders[msg.sender];
        bidding.commit = comm;
        counter +=1;
    }
    

    // cipher is the outcome of encrypting (x,r) by the public key of the auctioneer
    function reveal(string memory cipher) public{
        uint256 time = block.timestamp - timeDeployed;
        require((time>T1)&&(time<T2),"It is not the reveal time.");
        require(bidders[msg.sender].commit != 0, "No commitment was placed in your address");
        bidders[msg.sender].ciphertext = cipher;
        listOfBidders.push(msg.sender);
    }
    

    // called by auctioneer who has access to all bids
    function claimWinner(address probWinner, uint256 x, uint256 r) public{
        //hash comparison less gas required compared to string comparison
        require(keccak256(bytes(state))==keccak256("Init"),"Not valid state."); 
        uint256 time = block.timestamp - timeDeployed;
        require((time>T2)&&(time<T3),"It is not the claim the winner time.");
        require(keccak256(bytes(bidders[probWinner].ciphertext)) != keccak256(bytes("")), "Not a bidder."); 
        //also check if x,r are the commit values used by the probWinner.
        require(x*G +r*H == bidders[probWinner].commit, "The values are not the commit of this bidder"); // for given G,H
        winner = probWinner;
        highestBid = x;
        state = "Challenge";
    }


    // for a bidder Bi a commit is W1,1 = w1,1*G+r1,1*H , W2,1 = w2,1*G+r2,1*H, ... , W1,k = w1,k*G+r1,k*H , W2,k=w2,k*G+r2,k*H a list of [W11,W12,W21,W22,...,W1k,W2k]
    function ZPKCommit(address Bi, uint256[] memory commits) public{
        require(keccak256(bytes(state))==keccak256("Challenge"),"Not valid state.");
        uint256 time = block.timestamp - timeDeployed;
        require((time>T2)&&(time<T3),"It is not the right time.");
        require(keccak256(bytes(bidders[Bi].ciphertext)) != keccak256(bytes("")), "Not a bidder.");
        zpkCommits = commits;
        challengeBidder = Bi;
        challengeBlockNumber = block.number;
        state = "Verify";
    }


    // by knowing the challengeBlockNumber sends the appropriate responses based on the bits and the 
    // commits he sent along with the values of the bid the challengeBidder, response is a list with k items.
    function ZPKVerify(uint256[] memory response) public{
        uint parser;
        require(keccak256(bytes(state))==keccak256("Verify"), "Not valid state.");
        uint256 time = block.timestamp - timeDeployed;
        require((time>T2)&&(time<T3),"It is not the right time.");
        bytes32 h = keccak256(abi.encodePacked(challengeBlockNumber));
        for (uint j; j<k; j++){
            bytes1 b = h[32-j];
            if (b==0){
                require(checkFirstCase(response, j, parser), "There is a non verified bidder.");
                // first case verification Rj = w1j, r1j, w2j, r2j
                parser +=4;
            }else{
                require(checkSecondCase(response, j, parser), "There is a non verified bidder.");
                // second case verification Rj = (xj+wzj), (uj+rzj), z in{0,1}
                parser +=3;
            }
        }
        bidders[challengeBidder].validBid = true;

        // check delta value for inequality
        uint256 delta = (bidders[winner].commit - bidders[challengeBidder].commit)%q;
        if ((delta<q/2) && (delta>=0)){
            bidders[challengeBidder].validDelta = true;
        }
        state = "Challenge";
    }
        

    function checkFirstCase(uint256[] memory value, uint j, uint p) internal view returns(bool){
        if (((value[p]*G +value[p+1]*H) == zpkCommits[2*j]) && ((value[p+2]*G +value[p+3]*H) == zpkCommits[2*j+1])){
            return true;
        }
        return false;
    }


    function checkSecondCase(uint256[] memory value, uint j, uint p) internal view returns(bool){
        uint256 tempCommit = bidders[challengeBidder].commit;
        if ((value[p]*G +value[p+1]*H) == (tempCommit + zpkCommits[2*j+value[p+2]])) {
            return true;
        }
        return false;
    }


    //if the auctioneer keeps someone off the challenge the auction is not continued
    function VerifyAll() public{
        require(keccak256(bytes(state))==keccak256("Challenge"),"Not valid state.");
        uint256 time = block.timestamp - timeDeployed;
        require((time>T2)&&(time<T3),"It is not the right time.");
        for (uint i; i < listOfBidders.length; i++){
            if (listOfBidders[i] != winner){
                require(bidders[listOfBidders[i]].validBid == true, "There is a non valid bidder.");
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
            if ((keccak256(bytes(state))!=keccak256("ValidWinner"))||(keccak256(bytes(state))!=keccak256("WinnerPaid"))){
                for (uint i; i < listOfBidders.length; i++){
                    uint256 amount = ledger[listOfBidders[i]];
                    if (bidders[listOfBidders[i]].returned==false){
                        bidders[listOfBidders[i]].returned = true;
                        deposit = deposit - F;
                        payable(listOfBidders[i]).transfer(amount + F);
                    }            
                }
            }else{
                uint256 amount = ledger[auctioneer];
                if (auctioneerReturn==false){
                    auctioneerReturn = true;
                    deposit = deposit - F;
                    payable(auctioneer).transfer(amount + F);
                }
                for (uint i; i < listOfBidders.length; i++){
                    uint256 amount1 = ledger[listOfBidders[i]];
                    if ((bidders[listOfBidders[i]].returned==false)&&(listOfBidders[i]!=winner)){
                        bidders[listOfBidders[i]].returned = true;
                        deposit = deposit - F;
                        payable(listOfBidders[i]).transfer(amount1 + F);
                    }
                }

            }
        }
    }
    
}


// THIS CODE IMPLEMENTS THE PROTOCOL ONLY ONCE AND THE AUCTIONEER PROVIDES A LIT OF ALL THE BIDDERS ALONG 
// WITH ALL THE COMMITS AND LATER ALL THE RESPONSES.

    // // for every bidder i a commit is w1,i , r1,i , w2,i , r2,i
    // function ZPKCommit(address[] memory B, uint256[] memory commits) public{
    //     require(keccak256(bytes(state))==keccak256("Challenge"),"Not valid state.");
    //     uint256 time = block.timestamp - timeDeployed;
    //     require((time>T2)&&(time<T3),"It is not the right time.");
    //     for (uint i; i<B.length;i++){
    //         require(keccak256(bytes(bidders[B[i]].ciphertext)) != keccak256(bytes("")), "Not a bidder.");
    //     }
    //     zpkCommits = commits;
    //     challengeBidder = B;
    //     challengeBlockNumber = block.number;
    //     state = "Verify";
    // }


    // // by knowing the challengeBlockNumber sends the appropriate responses based on the bits and the 
    // // commits he sent aling with the values of the bid the bidders opened for auctioneer
    // function ZPKVerify(uint256[] memory response) public{
    //     require(keccak256(bytes(state))==keccak256("Verify"), "Not valid state.");
    //     uint256 time = block.timestamp - timeDeployed;
    //     require((time>T2)&&(time<T3),"It is not the right time.");
    //     bytes32 h = keccak256(abi.encodePacked(challengeBlockNumber));
    //     for (uint i; i<challengeBidder.length; i++){
    //         bytes1 b = h[32-i];
    //         if (b==0){
    //             require(checkFirstCase(response[i], i), "There is a non verified bidder.");
    //             // first case verification Rj = w1j, r1j, w2j, r2j
    //         }else{
    //             require(checkSecondCase(response[i], i), "There is a non verified bidder.");
    //             // second case verification Rj = (xj+wzj), (uj+rzj), z in{0,1}
    //         }
    //         bidders[challengeBidder[i]].validBid = true;
    //     }
    //     state = "Challenge";
    // }
        

    // function checkFirstCase(uint256 value, uint i) internal returns(bool){
    //     // by value being a list we check the following

    //     // if (((value[0]*G +value[1]*H) == zpkCommits[i][0]) && ((value[3]*G +value[4]*H) == zpkCommits[i][1])){
    //     //     return true;
    //     // }
    //     // return false;
    // }


    // function checkSecondCase(uint256 value, uint i) internal returns(bool){
    //     // by value being a list we check the following

    //     // uint256 tempCommit = bidders[challengeBidder[i]].commit;
    //     // if ((value[0]*G +value[1]*H) == (tempCommit + zpkCommits[i][value[2]]) {
    //     //     return true;
    //     // }
    //     // return false;
    // }