pragma solidity ^0.8.3;
// import "@nomiclabs/builder/console.sol";

contract Tester{
    
    bytes32 public Hashedresult;
    bytes32 public concatenatedHashedResult;
    bytes public bytesTest;
    bytes public concatenatedBytesTest;
    string public text = "500salt";
    bool public isItEqual;
    
    int256 value = 500;
    string salt = "salt";
    
    function test() public{
        
        
        bytesTest = abi.encodePacked(text);
        Hashedresult = keccak256(abi.encodePacked(text));
        
        concatenatedBytesTest = abi.encodePacked(value, salt);
        concatenatedHashedResult = keccak256(abi.encodePacked(value, salt));
        
        isItEqual = (Hashedresult == concatenatedHashedResult);
        
    }
    
    function stringToBytes32(string memory source) public pure returns (bytes32 results) {
    bytes memory tempEmptyStringTest = bytes(source);
    if (tempEmptyStringTest.length == 0) {
        return 0x0;
    }

    assembly {
        results := mload(add(source, 32))
    }
}
}