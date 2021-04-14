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
    string public state;
    
    struct Biddings {
        string ciphertext;
        uint256 commit;
    }
    mapping(address => Biddings) bidders;
    uint256 highestBid;
    address winner;
    uint256 timeDeployed;
    uint256 deposit;
    mapping(address => uint256) ledger;
    
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
    }
    
    function bid(uint256 comm) public payable {
        require((block.timestamp - timeDeployed)<T1, "The commitment period has passed.");
        require(msg.value>F,"Provide at least the appropriate amount.");
        ledger[msg.sender] = msg.value - F;
        deposit = deposit + F;
        Biddings memory bidding = bidders[msg.sender];
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
    }
    
}